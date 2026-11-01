require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module BookingProject
  class Application < Rails::Application
    config.load_defaults 7.1

    config.autoload_lib(ignore: %w(assets tasks))
    config.i18n.default_locale = :ru
    config.i18n.available_locales = [:en, :ru]
    config.time_zone = "Moscow"
    config.eager_load = false

    # Фиксированный secret_key_base для test-среды (не production)
    config.secret_key_base = "test_secret_key_base_#{"a" * 64}" if Rails.env.test?

    # Использование SQL-формата схемы для корректной поддержки PostgreSQL tsrange и GiST exclusion constraints
    config.active_record.schema_format = :ruby
  end
end
