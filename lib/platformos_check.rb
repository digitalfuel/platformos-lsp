# frozen_string_literal: true

require "liquid"

require_relative "platformos_check/version"
require_relative "platformos_check/bug"
require_relative "platformos_check/exceptions"
require_relative "platformos_check/json_helper"
require_relative "platformos_check/app_file_rewriter"
require_relative "platformos_check/app_file"
require_relative "platformos_check/yaml_file"
require_relative "platformos_check/translation_file"
require_relative "platformos_check/schema_file"
require_relative "platformos_check/config_file"
require_relative "platformos_check/user_schema_file"
require_relative "platformos_check/graphql_file"
require_relative "platformos_check/liquid_file"
require_relative "platformos_check/page_file"
require_relative "platformos_check/partial_file"
require_relative "platformos_check/form_file"
require_relative "platformos_check/layout_file"
require_relative "platformos_check/migration_file"
require_relative "platformos_check/sms_file"
require_relative "platformos_check/email_file"
require_relative "platformos_check/api_call_file"
require_relative "platformos_check/asset_file"
require_relative "platformos_check/json_file"
require_relative "platformos_check/analyzer"
require_relative "platformos_check/check"
require_relative "platformos_check/checks_tracking"
require_relative "platformos_check/liquid_check"
require_relative "platformos_check/html_check"
require_relative "platformos_check/yaml_check"
require_relative "platformos_check/cli"
require_relative "platformos_check/disabled_check"
require_relative "platformos_check/disabled_checks"
require_relative "platformos_check/regex_helpers"
require_relative "platformos_check/json_helpers"
require_relative "platformos_check/position_helper"
require_relative "platformos_check/position"
require_relative "platformos_check/checks"
require_relative "platformos_check/config"
require_relative "platformos_check/node"
require_relative "platformos_check/tags/base_tag_methods"
require_relative "platformos_check/tags/base"
require_relative "platformos_check/tags/base_block"
require_relative "platformos_check/tags/background"
require_relative "platformos_check/tags/cache"
require_relative "platformos_check/tags/export"
require_relative "platformos_check/tags/form"
require_relative "platformos_check/tags/function"
require_relative "platformos_check/tags/graphql"
require_relative "platformos_check/tags/hash_assign"
require_relative "platformos_check/tags/log"
require_relative "platformos_check/tags/parse_json"
require_relative "platformos_check/tags/print"
require_relative "platformos_check/tags/redirect_to"
require_relative "platformos_check/tags/render"
require_relative "platformos_check/tags/response_headers"
require_relative "platformos_check/tags/response_status"
require_relative "platformos_check/tags/return"
require_relative "platformos_check/tags/session"
require_relative "platformos_check/tags/sign_in"
require_relative "platformos_check/tags/spam_protection"
require_relative "platformos_check/tags/theme_render"
require_relative "platformos_check/tags/try"
require_relative "platformos_check/tags"
require_relative "platformos_check/liquid_node"
require_relative "platformos_check/html_node"
require_relative "platformos_check/offense"
require_relative "platformos_check/printer"
require_relative "platformos_check/json_printer"
require_relative "platformos_check/platformos_liquid"
require_relative "platformos_check/string_helpers"
require_relative "platformos_check/storage"
require_relative "platformos_check/file_system_storage"
require_relative "platformos_check/in_memory_storage"
require_relative "platformos_check/app"
require_relative "platformos_check/corrector"
require_relative "platformos_check/liquid_visitor"
require_relative "platformos_check/html_visitor"
require_relative "platformos_check/language_server"

Dir[__dir__ + "/platformos_check/checks/*.rb"].each { |file| require file }

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

module PlatformosCheck
  def self.debug?
    ENV["PLATFORMOS_CHECK_DEBUG"] == "true"
  end

  def self.debug_log_file
    ENV.fetch("PLATFORMOS_CHECK_DEBUG_LOG_FILE", nil)
  end

  def self.with_liquid_c_disabled
    if defined?(Liquid::C)
      was_enabled = Liquid::C.enabled
      Liquid::C.enabled = false if was_enabled
    end
    yield
  ensure
    Liquid::C.enabled = true if defined?(Liquid::C) && was_enabled
  end

  def self.log(message)
    bridge = LanguageServer::Bridge.new(LanguageServer::IOMessenger.new)
    bridge.log("###############\n #{message}\n##################")
  end
end
