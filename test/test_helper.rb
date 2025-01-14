# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require "platformos_check"
require "minitest/autorun"
require "minitest/focus"
require "mocha/minitest"
require "pry-byebug"
require "tmpdir"
require "pp"
require "debug"

Minitest::Test.make_my_diffs_pretty!

module Minitest
  class Test
    # Ported from active_support/testing/stream
    def silence_stream(stream)
      old_stream = stream.dup
      stream.reopen(IO::NULL)
      stream.sync = true
      yield
    ensure
      stream.reopen(old_stream)
      old_stream.close
    end

    # Ported from active_support/testing/stream
    def capture(stream)
      stream = stream.to_s
      captured_stream = Tempfile.new(stream)
      # rubocop:disable Security/Eval
      stream_io = eval("$#{stream}")
      # rubocop:enable Security/Eval
      origin_stream = stream_io.dup
      stream_io.reopen(captured_stream)

      yield

      stream_io.rewind
      captured_stream.read
    ensure
      captured_stream.close
      captured_stream.unlink
      stream_io.reopen(origin_stream)
    end

    def pretty_print(hash)
      io = StringIO.new
      PP.pp(hash, io)
      io.string
    end

    def parse_liquid(code)
      storage = make_storage("file.liquid" => code)
      PlatformosCheck::LiquidFile.new("file.liquid", storage)
    end

    def liquid_c_enabled?
      defined?(Liquid::C) && Liquid::C.enabled
    end

    def analyze_platformos_app(*check_classes, templates)
      analyzer = PlatformosCheck::Analyzer.new(make_platformos_app(templates), check_classes)
      analyzer.analyze_platformos_app
      analyzer.offenses
    end

    def analyze_single_file(file, *check_classes, templates)
      app = make_platformos_app(templates)
      analyzer = PlatformosCheck::Analyzer.new(app, check_classes)
      analyzer.analyze_files([app[file]], only_single_file: true)
      analyzer.offenses
    end

    def diagnose_platformos_app(*check_classes, templates)
      storage = PlatformosCheck::VersionedInMemoryStorage.new(templates)
      templates.each do |path, value|
        # set initial version of the files to 1
        storage.write(path, value, 1)
      end

      analyzer = PlatformosCheck::Analyzer.new(storage.platformos_app, check_classes)
      analyzer.analyze_platformos_app
      offenses = analyzer.offenses
      diagnostics_manager = PlatformosCheck::LanguageServer::DiagnosticsManager.new
      diagnostics_manager.build_diagnostics(offenses)
      {
        diagnostics_manager:,
        storage:
      }
    end

    def make_platformos_app(files = {})
      storage = make_storage(files)
      storage.platformos_app
    end

    def make_storage(files = {})
      return make_file_system_storage(files) if ENV['PLATFORMOS_CHECK_STORAGE'] == 'FileSystemStorage'

      make_in_memory_storage(files)
    end

    def make_file_system_storage(files = {})
      dir = Pathname.new(Dir.mktmpdir)
      files.each_pair do |name, content|
        path = dir.join(name)
        path.parent.mkpath
        path.write(content, mode: 'w+b')
      end
      at_exit { dir.rmtree }
      PlatformosCheck::FileSystemStorage.new(dir)
    end

    def make_in_memory_storage(files = {})
      PlatformosCheck::InMemoryStorage.new(files)
    end

    def fix_platformos_app(*check_classes, templates)
      platformos_app = make_platformos_app(templates)
      analyzer = PlatformosCheck::Analyzer.new(platformos_app, check_classes, true)
      analyzer.analyze_platformos_app
      analyzer.correct_offenses
      sources = platformos_app.liquid.map { |app_file| [app_file.relative_path.to_s, app_file.rewriter.to_s] }
      Hash[*sources.flatten]
    end

    def assert_offenses(output, offenses)
      # Making sure nothing blows up in the language_server
      offenses.each do |offense|
        assert(offense.start_row)
        assert(offense.start_column)
        assert(offense.end_row)
        assert(offense.end_column)
      end

      assert_equal(
        output.split("\n"),
        offenses
          .sort_by { |o| [o.location, o.message].join(' ') }
          .map(&:to_s)
      )
    end

    def assert_offenses_with_range(output, offenses)
      # Making sure nothing blows up in the language_server
      offenses.each do |offense|
        assert(offense.start_row)
        assert(offense.start_column)
        assert(offense.end_row)
        assert(offense.end_column)
      end

      assert_equal(
        output.chomp,
        offenses
          .sort_by { |o| [o.location_range, o.message].join(' ') }
          .map(&:to_s_range)
          .join("\n")
      )
    end

    def assert_includes_offense(offenses, output)
      assert_includes(offenses.sort_by(&:location).join("\n"), output.chomp)
    end

    module CompletionProviderTestHelper
      def assert_can_complete(provider, token, offset = 0, line = nil)
        context = mock_context(provider, token, offset, line)

        refute_empty(
          provider.completions(context).map { |x| x[:label] },
          <<~ERRMSG
            Expected completions at the specified cursor position:
            #{token}
            #{' ' * (token.size + offset)}^
          ERRMSG
        )
      end

      def assert_can_complete_with(provider, token, label, offset = 0, line = nil, relative_path = nil)
        context = mock_context(provider, token, offset, line, relative_path)

        assert_includes(
          provider.completions(context).map { |x| x[:label] },
          label,
          <<~ERRMSG
            Expected '#{label}' to be suggested at the specified cursor position:
            #{token}
            #{' ' * (token.size + offset)}^
          ERRMSG
        )
      end

      def assert_can_hover_with(provider, token, label, offset = 0, line = nil)
        context = mock_context(provider, token, offset, line)

        assert_includes(
          provider.completions(context)[:contents],
          label,
          <<~ERRMSG
            Expected '#{label}' to be suggested at the specified cursor position:
            #{token}
            #{' ' * (token.size + offset)}^
          ERRMSG
        )
      end

      def refute_can_complete(provider, token, offset = 0, line = nil)
        context = mock_context(provider, token, offset, line)

        assert_empty(
          provider.completions(context),
          <<~ERRMSG
            Expected no completions at the specified cursor location:
            #{token}
            #{' ' * (token.size + offset)}^
          ERRMSG
        )
      end

      def refute_can_complete_with(provider, token, label, offset = 0, line = nil, relative_path = nil)
        context = mock_context(provider, token, offset, line, relative_path)

        refute_includes(
          provider.completions(context).map { |x| x[:label] },
          label,
          <<~ERRMSG
            Expected '#{label}' not to be suggested at the specified cursor position:
            #{token}
            #{' ' * (token.size + offset)}^
          ERRMSG
        )
      end

      private

      def mock_context(provider, token, offset, line = nil, relative_path = "file:///fake_path")
        storage = provider.storage

        storage.stubs(:read).with(relative_path).returns(token)

        lines = token.split("\n")
        if line
          col = lines[line].size + offset
        else
          line = lines.size
          col = lines.last.size + offset
        end

        PlatformosCheck::LanguageServer::CompletionContext.new(storage, relative_path, line, col)
      end
    end

    class TracerCheck < PlatformosCheck::Check
      attr_reader :calls

      def initialize
        @calls = []
      end

      def respond_to?(method)
        method.to_s.start_with?("on_", "after_") || super
      end

      def method_missing(method, node)
        @calls << method
        @calls << node.value if node.literal?
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end

      def single_file_end_dependencies(liquid_file)
        # Ignore
      end

      def on_node(node)
        # Ignore, too noisy
      end

      def after_node(node)
        # Ignore, too noisy
      end
    end

    class MockMessenger < PlatformosCheck::LanguageServer::Messenger
      attr_accessor :logs, :sent_messages
      attr_writer :supports_work_done_progress

      def initialize
        @logs = []
        @sent_messages = []
        @supports_work_done_progress = false
        @queue = Queue.new
      end

      def read_message
        @queue.pop
      ensure
        raise PlatformosCheck::LanguageServer::DoneStreaming if @queue.closed?
      end

      def send_message(message_body)
        @sent_messages << JSON.parse(message_body, symbolize_names: true)
      end

      def log(s)
        logs << s
      end

      def close_input
        @queue.close
      end

      def close_output; end

      def send_mock_message(message)
        @queue << message
      end
    end
  end
end
