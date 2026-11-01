# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_global_defaults

  helper_method :active_bookings_count, :my_resources_count

  def active_bookings_count
    return 0 unless defined?(current_user) && current_user.present?
    current_user.bookings.where(status: "confirmed").where("upper(booking_period) >= ?", Time.current).count
  rescue StandardError
    0
  end

  def my_resources_count
    return 0 unless defined?(current_user) && current_user.present?
    current_user.resources.count
  rescue StandardError
    0
  end

  protected

  def set_global_defaults
    @active_bookings_count = active_bookings_count
    @my_resources_count = my_resources_count
  rescue StandardError
    @active_bookings_count = 0
    @my_resources_count = 0
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :phone])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone])
  end
end

