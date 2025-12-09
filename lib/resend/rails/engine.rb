# frozen_string_literal: true

module Resend
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace ActionMailbox

      initializer "resend-rails.add_routes" do |app|
        app.routes.prepend do
          scope "/rails/action_mailbox", module: "action_mailbox/ingresses" do
            post "/resend/inbound_emails" => "resend/inbound_emails#create", as: :rails_resend_inbound_emails
          end
        end
      end

      initializer "resend-rails.configure" do
        config.after_initialize do
          Resend::Rails.configure_api_key
        end
      end
    end
  end
end
