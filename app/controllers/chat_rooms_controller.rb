# frozen_string_literal: true

class ChatRoomsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat_room, only: [:show]
  before_action :authorize_participant!, only: [:show]

  # GET /chat или GET /chat_rooms
  def index
    @chat_rooms = ChatRoom.for_user(current_user).recent.includes(:customer, :owner, :resource, :booking)

    if @chat_rooms.any?
      redirect_to chat_room_path(@chat_rooms.first)
    else
      render :index
    end
  end

  # GET /chat_rooms/:id
  def show
    @chat_rooms = ChatRoom.for_user(current_user).recent.includes(:customer, :owner, :resource, :booking)
    @messages = @chat_room.chat_messages.includes(:user)
    @new_message = ChatMessage.new
    @interlocutor = @chat_room.interlocutor_for(current_user)
  end

  # POST /chat_rooms — начать или открыть 1-на-1 чат
  def create
    if params[:resource_id].present?
      resource = Resource.find_by(slug: params[:resource_id]) || Resource.find_by(id: params[:resource_id])
      if resource.nil?
        redirect_to resources_path, alert: "Объявление не найдено."
        return
      end

      owner = resource.user
      if owner.blank?
        redirect_to resource_path(resource.slug), alert: "У этого объявления пока не указан владелец."
        return
      end

      if owner.id == current_user.id
        redirect_to resource_path(resource.slug), alert: "Вы не можете начать чат со своим собственным объявлением."
        return
      end

      @chat_room = ChatRoom.find_or_create_for_resource(customer: current_user, resource: resource)
      redirect_to chat_room_path(@chat_room), notice: "Чат с автором объявления «#{resource.name}» открыт."
      return
    end

    if params[:booking_id].present?
      booking = Booking.find_by(id: params[:booking_id])
      if booking.nil?
        redirect_to chat_rooms_path, alert: "Бронирование не найдено."
        return
      end

      resource_owner = booking.resource&.user
      unless booking.user_id == current_user.id || (resource_owner && resource_owner.id == current_user.id)
        redirect_to bookings_path, alert: "У вас нет доступа к этому бронированию."
        return
      end

      if booking.user_id == resource_owner&.id
        redirect_to booking_path(booking), alert: "Вы являетесь и заказчиком, и владельцем объявления. Чат 1 на 1 не требуется."
        return
      end

      @chat_room = ChatRoom.find_or_create_for_booking(booking)
      redirect_to chat_room_path(@chat_room), notice: "Чат по бронированию ##{booking.id} открыт."
      return
    end

    redirect_to chat_rooms_path, alert: "Для открытия чата 1 на 1 выберите объявление или бронирование."
  end

  private

  def set_chat_room
    @chat_room = ChatRoom.find(params[:id])
  end

  def authorize_participant!
    unless @chat_room.participant?(current_user)
      redirect_to chat_rooms_path, alert: "У вас нет доступа к этому диалогу. Это приватный чат 1 на 1."
    end
  end
end
