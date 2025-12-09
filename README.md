# Resend Rails

Resend inbound email ingress for Action Mailbox.

This gem allows Rails applications to receive inbound emails via [Resend](https://resend.com) webhooks and process them using Action Mailbox.

## Installation

Add to your Gemfile:

```ruby
gem "resend-rails"
```

Then run:

```bash
bundle install
```

## Configuration

### 1. Configure Resend credentials

Use `bin/rails credentials:edit` to add your Resend credentials:

```yaml
resend:
  api_key: re_...
  signing_secret: whsec_...
```

Alternatively, use environment variables:

- `RESEND_API_KEY`
- `RESEND_SIGNING_SECRET`

### 2. Set the Action Mailbox ingress

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :resend
```

### 3. Configure your Resend webhook

In your [Resend dashboard](https://resend.com/webhooks), create a webhook pointing to:

```
https://your-app.com/rails/action_mailbox/resend/inbound_emails
```

Subscribe to the `email.received` event.

## How it works

1. Resend receives an email at your configured inbound address
2. Resend sends an `email.received` webhook to your application
3. The gem verifies the webhook signature using the Svix library
4. The full email data is fetched from the Resend API
5. An RFC 822 message is reconstructed (including inline and regular attachments)
6. The message is passed to Action Mailbox for routing to your mailboxes

## Requirements

- Ruby >= 3.1
- Rails >= 8.0 (Action Mailbox)
- [resend](https://github.com/resend/resend-ruby) gem >= 0.8

## License

MIT License. See [LICENSE](MIT-LICENSE) for details.
