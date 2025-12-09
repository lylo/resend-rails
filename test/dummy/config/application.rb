# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_mailbox/engine"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.0
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.active_storage.service = :test
    config.action_mailbox.ingress = :resend
    config.secret_key_base = "test_secret"
    config.root = File.dirname(__FILE__) + "/.."
  end
end
