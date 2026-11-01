# frozen_string_literal: true

module Api
  module V1
    class ResourcesController < ApplicationController
      # GET /api/v1/resources/:id/availability?date=YYYY-MM-DD
      # Возвращает почасовые слоты доступности для виджета календаря Vue.js
      def availability
        resource = Resource.find_by(slug: params[:id]) || Resource.find(params[:id])
        date_str = params[:date].presence || Date.current.to_s
        slots    = resource.hourly_slots_for(date_str)

        render json: {
          resource_id: resource.id,
          resource_name: resource.name,
          hourly_rate: resource.hourly_rate,
          available_from_time: resource.available_from_time,
          available_to_time: resource.available_to_time,
          available_from_date: resource.available_from_date,
          available_to_date: resource.available_to_date,
          date: date_str,
          slots: slots
        }
      end
    end
  end
end
