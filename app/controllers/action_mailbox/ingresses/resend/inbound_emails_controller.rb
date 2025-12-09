# frozen_string_literal: true

require "mail"
require "open-uri"
require "nokogiri"

module ActionMailbox
  module Ingresses
    module Resend
      class InboundEmailsController < ActionMailbox::BaseController
        before_action :verify_webhook

        def create
          return head :ok unless params[:type] == "email.received"

          email = ::Resend::Emails::Receiving.get(params.dig(:data, :email_id))
          ActionMailbox::InboundEmail.create_and_extract_message_id!(build_rfc822(email.to_h.with_indifferent_access))
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

        def build_rfc822(data)
          inline_attachments, regular_attachments = fetch_attachments(data)
          html_body = replace_data_uris_with_cids(data["html"], inline_attachments)

          mail = Mail.new
          mail.from = data["from"]
          mail.to = data["to"]
          mail.cc = data["cc"] if data["cc"].present?
          mail.subject = data["subject"]
          mail.message_id = data["message_id"] if data["message_id"].present?

          build_mail_body(mail, data["text"], html_body, inline_attachments, regular_attachments)
          mail.to_s
        end

        def fetch_attachments(data)
          return [[], []] if data["attachments"].blank?

          inline, regular = [], []

          data["attachments"].each do |meta|
            att = ::Resend::Emails::Receiving::Attachments.get(email_id: data["id"], id: meta["id"])
            att = att.to_h.with_indifferent_access if att.respond_to?(:to_h)
            next unless att["download_url"]

            content = URI.open(att["download_url"]).read
            attachment = { filename: meta["filename"], content_type: meta["content_type"], content: content, content_id: meta["content_id"]&.delete("<>") }

            meta["content_disposition"] == "inline" ? inline << attachment : regular << attachment
          end

          [inline, regular]
        end

        def replace_data_uris_with_cids(html, inline_attachments)
          return html if html.blank? || inline_attachments.empty?

          cid_map = inline_attachments.to_h { |a| [a[:filename], a[:content_id]] }
          doc = Nokogiri::HTML.fragment(html)

          doc.css("img[src^='data:']").each do |img|
            cid = cid_map[img["alt"]]
            img["src"] = "cid:#{cid}" if cid
          end

          doc.to_html
        end

        def build_mail_body(mail, text, html, inline_attachments, regular_attachments)
          body = build_body_part(text, html, inline_attachments)

          if regular_attachments.any?
            mail.content_type = "multipart/mixed"
            mail.add_part(body)
            regular_attachments.each { |a| mail.add_part(attachment_part(a, "attachment")) }
          elsif body.multipart?
            mail.content_type = body.content_type
            body.parts.each { |p| mail.add_part(p) }
          else
            mail.content_type = body.content_type
            mail.body = body.body.to_s
          end
        end

        def build_body_part(text, html, inline_attachments)
          text_part = text.present? ? make_part("text/plain; charset=UTF-8", text) : nil
          html_part = html.present? ? make_part("text/html; charset=UTF-8", html) : nil

          if inline_attachments.any? && html_part
            related = Mail::Part.new.tap { |p| p.content_type = "multipart/related" }
            if text_part
              alt = Mail::Part.new.tap { |p| p.content_type = "multipart/alternative" }
              alt.add_part(text_part)
              alt.add_part(html_part)
              related.add_part(alt)
            else
              related.add_part(html_part)
            end
            inline_attachments.each { |a| related.add_part(attachment_part(a, "inline")) }
            related
          elsif text_part && html_part
            alt = Mail::Part.new.tap { |p| p.content_type = "multipart/alternative" }
            alt.add_part(text_part)
            alt.add_part(html_part)
            alt
          else
            text_part || html_part || make_part("text/plain; charset=UTF-8", "")
          end
        end

        def make_part(content_type, body)
          Mail::Part.new.tap { |p| p.content_type = content_type; p.body = body }
        end

        def attachment_part(att, disposition)
          Mail::Part.new.tap do |p|
            p.content_type = att[:content_type]
            p.content_disposition = "#{disposition}; filename=\"#{att[:filename]}\""
            p.content_transfer_encoding = "base64"
            p.body = Base64.strict_encode64(att[:content])
            p.content_id = att[:content_id] if disposition == "inline" && att[:content_id]
          end
        end
      end
    end
  end
end
