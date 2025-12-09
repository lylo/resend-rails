# frozen_string_literal: true

module ActionMailbox
  module Ingresses
    module Resend
      # Ingests inbound emails from Resend webhooks.
      #
      # == Usage
      #
      # 1. Add to your Gemfile: +gem "resend-rails"+
      #
      # 2. Configure credentials (+bin/rails credentials:edit+):
      #
      #        resend:
      #          api_key: re_...
      #          signing_secret: whsec_...
      #
      # 3. Set ingress: +config.action_mailbox.ingress = :resend+
      #
      # 4. Configure Resend webhook to POST to +/rails/action_mailbox/resend/inbound_emails+
      #
      class InboundEmailsController < ActionMailbox::BaseController
        before_action :verify_webhook

        def create
          return head :ok unless params[:type] == "email.received"

          email = ::Resend::Emails::Receiving.get(params.dig(:data, :email_id))
          ActionMailbox::InboundEmail.create_and_extract_message_id!(build_rfc822(email))
          head :no_content
        end

        private
          def verify_webhook
            ::Resend::Webhooks.verify(
              payload: request.raw_post,
              headers: {
                "svix_id" => request.headers["Svix-Id"],
                "svix_timestamp" => request.headers["Svix-Timestamp"],
                "svix_signature" => request.headers["Svix-Signature"]
              },
              webhook_secret: signing_secret
            )
          rescue StandardError
            head :unauthorized
          end

          def signing_secret
            Rails.application.credentials.dig(:resend, :signing_secret) || ENV["RESEND_SIGNING_SECRET"]
          end

          def build_rfc822(data)
            mail = Mail.new
            mail.from = data["from"]
            mail.to = data["to"]
            mail.cc = data["cc"] if data["cc"].present?
            mail.subject = data["subject"]
            mail.message_id = data["message_id"] if data["message_id"].present?
            set_body(mail, data)
            add_attachments(mail, data) if data["attachments"].present?

            "X-Original-To: #{Array(data["to"]).first}\n#{mail}"
          end

          def set_body(mail, data)
            if data["text"].present? && data["html"].present?
              mail.text_part { body data["text"] }
              mail.html_part { body data["html"] }
            elsif data["html"].present?
              mail.content_type = "text/html; charset=UTF-8"
              mail.body = data["html"]
            else
              mail.body = data["text"] || ""
            end
          end

          def add_attachments(mail, data)
            data["attachments"].each do |meta|
              attachment = ::Resend::Emails::Receiving::Attachments.get(params.dig(:data, :email_id), meta["id"])
              next unless attachment&.dig("download_url")

              content = URI.open(attachment["download_url"]).read rescue next
              mail.attachments[meta["filename"]] = { content_type: meta["content_type"], content: content }
            end
          end
      end
    end
  end
end
