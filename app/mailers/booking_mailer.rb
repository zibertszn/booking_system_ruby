# frozen_string_literal: true

class BookingMailer < ApplicationMailer
  # Письмо подтверждения бронирования
  def confirmation_email(booking)
    @booking  = booking
    @resource = booking.resource
    @user     = booking.user

    mail(
      to: @booking.contact_email,
      subject: "Подтверждение бронирования ##{@booking.id} — #{@resource.name}"
    )
  end

  # Письмо об отмене бронирования
  def cancellation_email(booking)
    @booking  = booking
    @resource = booking.resource
    @user     = booking.user

    mail(
      to: @booking.contact_email,
      subject: "Отмена бронирования ##{@booking.id} — #{@resource.name}"
    )
  end
end
