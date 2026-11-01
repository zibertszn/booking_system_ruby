source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby ">= 3.1.0"

# Классический стек Ruby on Rails (MPA + Vue.js виджеты + PostgreSQL)
gem "rails", "~> 7.1.3"
gem "sprockets-rails"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"

# Аутентификация и авторизация (Devise)
gem "devise", "~> 4.9"

# Ускорение загрузки
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "shoulda-matchers", "~> 6.0"
end

group :development do
  gem "web-console"
  gem "letter_opener"
end
