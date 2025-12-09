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
end
