# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :set_message, only: [:show, :toggle_star, :toggle_read, :move]

  def index
    @folder = "inbox"
    @messages = current_contact.received_messages.inbox.includes(:labels).newest_first
    render_message_list_or_full
  end

  def sent
    @folder = "sent"
    @messages = current_contact.sent_messages.sent_box.includes(:labels).newest_first
    render_message_list_or_full
  end

  def archive
    @folder = "archive"
    @messages = current_contact.received_messages.archived.includes(:labels).newest_first
    render_message_list_or_full
  end

  def trash
    @folder = "trash"
    @messages = current_contact.received_messages.trashed.includes(:labels).newest_first
    render_message_list_or_full
  end

  def show
    @message.mark_as_read!
    @message = @message
    render :show, layout: false
  end

  def create
    @message = Message.new(
      subject: params[:subject] || params.dig(:message, :subject),
      body: params[:body] || params.dig(:message, :body),
      sender: current_contact,
      recipient_id: params[:recipient_id] || params.dig(:message, :recipient_id),
      replied_to_id: params[:replied_to_id] || params.dig(:message, :replied_to_id),
      label: "sent",
      read_at: Time.current
    )

    if @message.save
      redirect_to root_path, notice: "Message sent!"
    else
      redirect_to root_path, alert: "Failed to send message."
    end
  end

  def search
    query = params[:q].to_s.strip
    @messages = if query.present?
      current_contact.received_messages
        .where("subject LIKE :q OR body LIKE :q", q: "%#{query}%")
        .includes(:labels)
        .newest_first
    else
      current_contact.received_messages.inbox.includes(:labels).newest_first
    end
    @folder = query.present? ? "search" : "inbox"

    render_message_list_or_full
  end

  def toggle_star
    @message.toggle_starred!
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          @message,
          MessageRowComponent.new(message: @message)
        )
      end
      format.html { redirect_to root_path }
    end
  end

  def toggle_read
    if @message.read?
      @message.update!(read_at: nil)
    else
      @message.mark_as_read!
    end
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          @message,
          MessageRowComponent.new(message: @message)
        )
      end
      format.html { redirect_to root_path }
    end
  end

  def move
    @message.update!(label: params[:label])
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@message)
      end
      format.html { redirect_to root_path }
    end
  end

  private

  def set_message
    @message = Message.find(params[:id])
  end

  def render_message_list_or_full
    @contacts = Contact.where.not(id: current_contact.id).order(:name)
    if turbo_frame_request?
      render :message_list_frame, layout: false
    else
      render :index
    end
  end
end
