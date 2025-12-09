# frozen_string_literal: true

require "resend"

module Resend
  module Rails
    class << self
      def configure_api_key
        return if ::Resend.api_key.present?

        if (api_key = ::Rails.application.credentials.dig(:resend, :api_key) || ENV["RESEND_API_KEY"])
          ::Resend.api_key = api_key
        end
      end
    end
  end
end

require "resend/rails/engine" if defined?(::Rails::Engine)
