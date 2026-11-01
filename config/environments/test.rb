# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false

  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "example.com" }

  config.active_job.queue_adapter = :test

  config.active_support.deprecation = :stderr

  config.active_storage.service = :test

  # Фиксированный ключ для тестовой среды (не используется в production)
  config.secret_key_base = "test_secret_key_base_#{"a" * 64}"
end
