# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "bundler/setup"
require "minitest/autorun"
require "webmock/minitest"

require_relative "dummy/config/application"
require "resend-rails"

Dummy::Application.initialize!

ActiveRecord::Schema.define do
  create_table :action_mailbox_inbound_emails, force: true do |t|
    t.integer :status, default: 0, null: false
    t.string :message_id, null: false
    t.string :message_checksum, null: false
    t.timestamps
  end

  create_table :active_storage_blobs, force: true do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.timestamps
    t.index [:key], unique: true
  end

  create_table :active_storage_attachments, force: true do |t|
    t.string :name, null: false
    t.string :record_type, null: false
    t.bigint :record_id, null: false
    t.bigint :blob_id, null: false
    t.timestamps
  end
end
