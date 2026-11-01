# frozen_string_literal: true

class ChatMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat_room
  before_action :authorize_participant!

  # POST /chat_rooms/:chat_room_id/chat_messages
  # Принимает сообщение через Hotwire Turbo Streams или HTML
  def create
    @chat_message = @chat_room.chat_messages.build(chat_message_params)
    @chat_message.user = current_user

    if @chat_message.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(
              "new_chat_message_form_#{@chat_room.id}",
              partial: "chat_messages/form",
              locals: { chat_room: @chat_room, chat_message: ChatMessage.new }
            )
          ]
        end
        format.html { redirect_to chat_room_path(@chat_room) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(
              "new_chat_message_form_#{@chat_room.id}",
              partial: "chat_messages/form",
              locals: { chat_room: @chat_room, chat_message: @chat_message }
            )
          ]
        end
        format.html { redirect_to chat_room_path(@chat_room), alert: @chat_message.errors.full_messages.join(", ") }
      end
    end
  end

  private

  def set_chat_room
    @chat_room = ChatRoom.find(params[:chat_room_id])
  end

  def authorize_participant!
    unless @chat_room.participant?(current_user)
      respond_to do |format|
        format.turbo_stream { head :forbidden }
        format.html { redirect_to chat_rooms_path, alert: "У вас нет доступа к отправке сообщений в этот диалог." }
      end
    end
  end

  def chat_message_params
    params.require(:chat_message).permit(:content)
  end
end
