# frozen_string_literal: true

require "test_helper"

class ActionMailbox::Ingresses::Resend::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Resend.api_key = "re_test_key"
    ENV["RESEND_SIGNING_SECRET"] = "whsec_testsecret"
  end

  test "receiving an inbound email" do
    stub_resend_api

    ::Resend::Webhooks.stub :verify, true do
      assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
        post "/rails/action_mailbox/resend/inbound_emails",
          params: { type: "email.received", data: { email_id: "test-id" } }.to_json,
          headers: json_headers
      end

      assert_response :no_content
    end
  end

  test "acknowledging non-email events" do
    ::Resend::Webhooks.stub :verify, true do
      post "/rails/action_mailbox/resend/inbound_emails",
        params: { type: "email.sent" }.to_json,
        headers: json_headers

      assert_response :ok
    end
  end

  test "rejecting invalid signatures" do
    ::Resend::Webhooks.stub :verify, proc { raise StandardError, "Invalid signature" } do
      post "/rails/action_mailbox/resend/inbound_emails",
        params: { type: "email.received" }.to_json,
        headers: json_headers

      assert_response :unauthorized
    end
  end

  test "receiving an email with inline attachments" do
    stub_resend_api_with_inline_attachment

    ::Resend::Webhooks.stub :verify, true do
      assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
        post "/rails/action_mailbox/resend/inbound_emails",
          params: { type: "email.received", data: { email_id: "email-with-attachment" } }.to_json,
          headers: json_headers
      end

      assert_response :no_content

      inbound_email = ActionMailbox::InboundEmail.last
      mail = Mail.new(inbound_email.raw_email.download)

      # Should be multipart/related for inline attachments
      assert_equal "multipart/related", mail.mime_type

      # HTML should have cid: reference, not data: URI
      assert_includes mail.html_part.decoded, "cid:ii_abc123"
      assert_not_includes mail.html_part.decoded, "data:image"

      # Should have the inline attachment
      assert_equal 1, mail.attachments.count
      attachment = mail.attachments.first
      assert_equal "image.jpg", attachment.filename
      assert_equal "<ii_abc123>", attachment.content_id
    end
  end

  test "receiving an email with regular attachments" do
    stub_resend_api_with_regular_attachment

    ::Resend::Webhooks.stub :verify, true do
      assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
        post "/rails/action_mailbox/resend/inbound_emails",
          params: { type: "email.received", data: { email_id: "email-with-regular-attachment" } }.to_json,
          headers: json_headers
      end

      assert_response :no_content

      inbound_email = ActionMailbox::InboundEmail.last
      mail = Mail.new(inbound_email.raw_email.download)

      # Should be multipart/mixed for regular attachments
      assert_equal "multipart/mixed", mail.mime_type

      # Should have the attachment
      assert_equal 1, mail.attachments.count
      attachment = mail.attachments.first
      assert_equal "document.pdf", attachment.filename
    end
  end

  private
    def json_headers
      { "CONTENT_TYPE" => "application/json" }
    end

    def stub_resend_api
      stub_request(:get, "https://api.resend.com/emails/receiving/test-id")
        .to_return(status: 200, body: {
          from: "sender@example.com",
          to: ["recipient@example.com"],
          subject: "Test",
          text: "Hello",
          message_id: "<test@example.com>",
          attachments: []
        }.to_json, headers: { "Content-Type" => "application/json" })
    end

    def stub_resend_api_with_inline_attachment
      image_content = "FAKE_IMAGE_BYTES"

      stub_request(:get, "https://api.resend.com/emails/receiving/email-with-attachment")
        .to_return(status: 200, body: {
          id: "email-with-attachment",
          from: "sender@example.com",
          to: ["recipient@example.com"],
          subject: "Test with image",
          text: "See image",
          html: "<p>See image</p><img src=\"data:image/jpeg;base64,#{Base64.strict_encode64(image_content)}\" alt=\"image.jpg\">",
          message_id: "<inline-test@example.com>",
          attachments: [{
            id: "att-123",
            filename: "image.jpg",
            content_type: "image/jpeg",
            content_id: "<ii_abc123>",
            content_disposition: "inline",
            size: image_content.bytesize
          }]
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:get, "https://api.resend.com/emails/receiving/email-with-attachment/attachments/att-123")
        .to_return(status: 200, body: {
          id: "att-123",
          filename: "image.jpg",
          content_type: "image/jpeg",
          download_url: "https://cdn.resend.com/att-123"
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:get, "https://cdn.resend.com/att-123")
        .to_return(status: 200, body: image_content, headers: { "Content-Type" => "image/jpeg" })
    end

    def stub_resend_api_with_regular_attachment
      pdf_content = "FAKE_PDF_BYTES"

      stub_request(:get, "https://api.resend.com/emails/receiving/email-with-regular-attachment")
        .to_return(status: 200, body: {
          id: "email-with-regular-attachment",
          from: "sender@example.com",
          to: ["recipient@example.com"],
          subject: "Test with PDF",
          text: "See attached",
          html: "<p>See attached</p>",
          message_id: "<regular-test@example.com>",
          attachments: [{
            id: "att-456",
            filename: "document.pdf",
            content_type: "application/pdf",
            content_disposition: "attachment",
            size: pdf_content.bytesize
          }]
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:get, "https://api.resend.com/emails/receiving/email-with-regular-attachment/attachments/att-456")
        .to_return(status: 200, body: {
          id: "att-456",
          filename: "document.pdf",
          content_type: "application/pdf",
          download_url: "https://cdn.resend.com/att-456"
        }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:get, "https://cdn.resend.com/att-456")
        .to_return(status: 200, body: pdf_content, headers: { "Content-Type" => "application/pdf" })
    end
end
