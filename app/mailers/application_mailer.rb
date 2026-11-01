# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "noreply@booking-system.local"
  layout "mailer"
end
