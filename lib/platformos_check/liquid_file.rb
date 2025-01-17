# frozen_string_literal: true

module PlatformosCheck
  class LiquidFile < AppFile
    def write
      content = rewriter.to_s
      return unless source != content

      @storage.write(@relative_path, content.gsub("\n", @eol))
      @source = content
      @rewriter = nil
    end

    def liquid?
      true
    end

    def notification?
      false
    end

    def migration?
      false
    end

    def page?
      false
    end

    def form?
      false
    end

    def partial?
      false
    end

    def layout?
      false
    end

    def rewriter
      @rewriter ||= AppFileRewriter.new(@relative_path, source)
    end

    def source_excerpt(line)
      original_lines = source.split("\n")
      original_lines[bounded(0, line - 1, original_lines.size - 1)].strip
    rescue StandardError => e
      PlatformosCheck.bug(<<~EOS)
        Exception while running `source_excerpt(#{line})`:
        ```
        #{e.class}: #{e.message}
          #{e.backtrace.join("\n  ")}
        ```

        path: #{path}

        source:
        ```
        #{source}
        ```
      EOS
    end

    def parse
      @ast ||= self.class.parse(source)
    end

    def warnings
      @ast.warnings
    end

    def root
      parse.root
    end

    def self.parse(source)
      Tags.register_tags!
      Liquid::Template.parse(
        source,
        line_numbers: true,
        error_mode: :warn,
        disable_liquid_c_nodes: true
      )
    end

    private

    def bounded(lower, x, upper)
      [lower, [x, upper].min].max
    end
  end
end
