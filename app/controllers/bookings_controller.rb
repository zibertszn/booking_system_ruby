# frozen_string_literal: true

class BookingsController < ApplicationController
  before_action :authenticate_user!

  # GET /bookings — Личный кабинет («Мои бронирования»)
  def index
    @status_filter = params[:status].presence || "all"
    scope = current_user.bookings.includes(:resource).recent

    @bookings = case @status_filter
                when "confirmed" then scope.confirmed
                when "cancelled" then scope.cancelled
                else scope
                end

    @active_count = current_user.bookings.confirmed.count
    @total_hours  = current_user.bookings.confirmed.sum(:duration_hours)
    @total_spent  = current_user.bookings.confirmed.sum(:total_price)
  end

  # GET /bookings/:id — Экран успешного бронирования
  def show
    @booking  = current_user.bookings.includes(:resource).find(params[:id])
    @resource = @booking.resource
  end

  # POST /bookings — Создание новой брони с защитой от овербукинга
  def create
    @resource = Resource.find(booking_params[:resource_id])
    @booking  = current_user.bookings.build(booking_params)

    ActiveRecord::Base.transaction do
      if @booking.save
        respond_to do |format|
          format.html { redirect_to booking_path(@booking), notice: "Бронирование успешно оформлено. Подтверждение отправлено на почту." }
          format.json { render json: { booking: @booking, redirect_url: booking_path(@booking) }, status: :created }
        end
      else
        respond_to do |format|
          format.html do
            flash[:alert] = @booking.errors.full_messages.join(", ")
            redirect_to resource_path(@resource, date: @booking.booking_date)
          end
          format.json { render json: { errors: @booking.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    error_msg = "Выбранный временной слот уже занят другим бронированием."
    respond_to do |format|
      format.html { redirect_to resource_path(@resource), alert: error_msg }
      format.json { render json: { errors: [error_msg], details: e.message }, status: :conflict }
    end
  end

  # PATCH/POST /bookings/:id/cancel — Отмена бронирования
  def cancel
    @booking = current_user.bookings.find(params[:id])
    @booking.cancel!

    respond_to do |format|
      format.html { redirect_to bookings_path, notice: "Бронирование ##{@booking.id} отменено. Слот освобожден." }
      format.json { render json: { booking: @booking, status: "cancelled" } }
    end
  end

  private

  def booking_params
    params.require(:booking).permit(
      :resource_id,
      :booking_date,
      :start_time,
      :end_time,
      :purpose,
      :contact_name,
      :contact_email,
      :contact_phone
    )
  end
end
