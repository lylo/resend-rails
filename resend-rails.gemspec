# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "resend-rails"
  spec.version = "0.1.0"
  spec.authors = ["Olly Headey"]
  spec.email = ["olly@hey.com"]

  spec.summary = "Resend inbound email ingress for Action Mailbox"
  spec.description = "Provides a Resend ingress for Action Mailbox, allowing Rails applications to receive inbound emails via Resend webhooks."
  spec.homepage = "https://github.com/lylo/resend-rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["{app,lib}/**/*", "MIT-LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "actionmailbox", ">= 8.0"
  spec.add_dependency "resend", ">= 0.8"
end
