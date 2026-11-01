# frozen_string_literal: true

module Api
  module V1
    class AvailabilitiesController < ApplicationController
      # POST /api/v1/availabilities/check
      # Асинхронная проверка выбранного диапазона времени из компонента Vue.js
      def check
        resource   = Resource.find(params[:resource_id])
        date_str   = params[:booking_date].to_s
        start_time = params[:start_time].to_s
        end_time   = params[:end_time].to_s

        starts_at = Time.zone.parse("#{date_str} #{start_time}")
        ends_at   = Time.zone.parse("#{date_str} #{end_time}")

        overlap = Booking
          .where(resource_id: resource.id, status: "confirmed")
          .where("booking_period && tsrange(?, ?, '[)')", starts_at, ends_at)
          .exists?

        duration_hours = [(Booking.time_to_minutes(end_time) - Booking.time_to_minutes(start_time)) / 60, 1].max

        render json: {
          available: !overlap && ends_at > starts_at,
          duration_hours: duration_hours,
          total_price: duration_hours * resource.hourly_rate
        }
      end
    end
  end
end
