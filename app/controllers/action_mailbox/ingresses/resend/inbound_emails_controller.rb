# frozen_string_literal: true

require "open-uri"

module ActionMailbox
  # Ingests inbound emails from Resend. Requires a webhook configured to send +email.received+ events.
  #
  # Authenticates requests by verifying the Svix webhook signature using the signing secret from
  # the application's encrypted credentials or an environment variable. See the Usage section below.
  #
  # This ingress downloads the raw RFC 822 email directly from Resend's API. You must have
  # raw email access enabled on your Resend account.
  #
  # Returns:
  #
  # - <tt>204 No Content</tt> if an inbound email is successfully recorded and enqueued for routing to the appropriate mailbox
  # - <tt>200 OK</tt> if the webhook event is not an +email.received+ event (acknowledged but not processed)
  # - <tt>401 Unauthorized</tt> if the request's signature could not be validated
  # - <tt>500 Server Error</tt> if the signing secret is not configured, if raw email access is not enabled,
  #   or if one of the Active Record database, the Active Storage service, or the Active Job backend is misconfigured or unavailable
  #
  # == Usage
  #
  # 1. Tell Action Mailbox to accept emails from Resend:
  #
  #        # config/environments/production.rb
  #        config.action_mailbox.ingress = :resend
  #
  # 2. Configure your Resend API key and webhook signing secret.
  #
  #    Use <tt>bin/rails credentials:edit</tt> to add the credentials to your application's encrypted credentials:
  #
  #        resend:
  #          api_key: re_...
  #          signing_secret: whsec_...
  #
  #    Alternatively, provide the credentials in the +RESEND_API_KEY+ and +RESEND_SIGNING_SECRET+ environment variables.
  #
  # 3. {Configure Resend}[https://resend.com/webhooks] to send webhooks to
  #    +/rails/action_mailbox/resend/inbound_emails+ for the +email.received+ event.
  #
  #    If your application lives at <tt>https://example.com</tt>, configure your Resend webhook with the URL:
  #
  #        https://example.com/rails/action_mailbox/resend/inbound_emails
  #
  class Ingresses::Resend::InboundEmailsController < ActionMailbox::BaseController
    before_action :verify_webhook

    def create
      return head :ok unless params[:type] == "email.received"

      email_data = ::Resend::Emails::Receiving.get(params.dig(:data, :email_id)).to_h
      raw_email = download_raw_email(email_data)

      ActionMailbox::InboundEmail.create_and_extract_message_id!(raw_email)
      head :no_content
    end

    private

      def verify_webhook
        ::Resend::Webhooks.verify(
          payload: request.raw_post,
          headers: {
            svix_id: request.headers["Svix-Id"],
            svix_timestamp: request.headers["Svix-Timestamp"],
            svix_signature: request.headers["Svix-Signature"]
          },
          webhook_secret: Rails.application.credentials.dig(:resend, :signing_secret) || ENV["RESEND_SIGNING_SECRET"]
        )
      rescue StandardError
        head :unauthorized
      end

      def download_raw_email(email_data)
        download_url = email_data.dig(:raw, "download_url")
        raise "Raw email not available from Resend" unless download_url

        URI.open(download_url, open_timeout: 10, read_timeout: 30, &:read)
      end
  end
end
