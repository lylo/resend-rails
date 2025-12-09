# resend-rails

Resend inbound email ingress for Action Mailbox.

## Installation

Add to your Gemfile:

```ruby
gem "resend-rails"
```

## Configuration

1. Add your Resend credentials to `config/credentials.yml.enc`:

```yaml
resend:
  api_key: re_...
  signing_secret: whsec_...
```

Or use environment variables: `RESEND_API_KEY` and `RESEND_SIGNING_SECRET`

2. Configure Action Mailbox:

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :resend
```

3. Configure Resend to send `email.received` webhooks to:

```
https://your-app.com/rails/action_mailbox/resend/inbound_emails
```

## How it works

1. Resend receives an email and sends a webhook to your app
2. The webhook signature is verified using `Resend::Webhooks.verify`
3. The full email is fetched from the Resend API
4. An RFC 822 message is constructed and passed to Action Mailbox

## License

MIT
