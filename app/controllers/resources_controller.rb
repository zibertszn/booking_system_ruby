# frozen_string_literal: true

class ResourcesController < ApplicationController
  before_action :authenticate_user!, only: [:my, :edit, :update, :destroy, :update_image]
  before_action :set_my_resource, only: [:edit, :update, :destroy, :update_image]

  # GET / or GET /resources
  def index
    @selected_category = params[:category].presence || "all"
    @search_query      = params[:q].to_s.strip

    @resources = Resource
      .by_category(@selected_category)
      .search_query(@search_query)
      .order(id: :desc)
  end

  # GET /my_resources — Мои объявления текущего пользователя
  def my
    @selected_category = params[:category].presence || "all"
    scope = current_user.resources.order(id: :desc)
    @resources = scope.by_category(@selected_category)
    @total_count = scope.count
    @rooms_count = scope.where(category: "rooms").count
    @equipment_count = scope.where(category: "equipment").count
    @specialists_count = scope.where(category: "specialists").count
  end

  # GET /resources/:id
  def show
    @resource = Resource.find_by(slug: params[:id]) || Resource.find(params[:id])
    @initial_date = params[:date].presence || Date.current.to_s
    @initial_slots = @resource.hourly_slots_for(@initial_date)
  end

  # GET /resources/new
  def new
    @resource = Resource.new(category: "rooms", capacity: 6, hourly_rate: 1500, rate_unit: "hour")
  end

  # GET /resources/:id/edit — Редактирование объявления
  def edit
  end

  # POST /resources — Создание нового ресурса с пользовательским изображением
  def create
    @resource = Resource.new(resource_params)
    @resource.user = current_user if user_signed_in?

    uploaded_url = store_uploaded_image(params[:resource][:image_file], params[:resource][:image_data])
    @resource.image_url = uploaded_url if uploaded_url.present?
    @resource.image_url = "/images/room_alpha.svg" if @resource.image_url.blank?

    if params[:resource][:amenities_text].present?
      @resource.amenities = params[:resource][:amenities_text].split(",").map(&:strip).reject(&:blank?)
    end

    if @resource.save
      redirect_to resource_path(@resource.slug), notice: "Ресурс «#{@resource.name}» успешно создан со своим изображением."
    else
      flash.now[:alert] = @resource.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /resources/:id — Изменение объявления
  def update
    uploaded_url = store_uploaded_image(params[:resource][:image_file], params[:resource][:image_data])
    update_params = resource_params.to_h
    update_params[:image_url] = uploaded_url if uploaded_url.present?

    if params[:resource][:amenities_text].present?
      update_params[:amenities] = params[:resource][:amenities_text].split(",").map(&:strip).reject(&:blank?)
    end

    if @resource.update(update_params)
      redirect_to my_resources_path, notice: "Объявление «#{@resource.name}» успешно обновлено."
    else
      flash.now[:alert] = @resource.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /resources/:id — Удаление объявления
  def destroy
    resource_name = @resource.name
    @resource.destroy
    redirect_to my_resources_path, notice: "Объявление «#{resource_name}» успешно удалено."
  end

  # POST/PATCH /resources/:id/update_image — Загрузка или смена изображения существующего ресурса (только для автора)
  def update_image
    uploaded_url = store_uploaded_image(params[:image_file], params[:image_data])
    custom_url   = params[:image_url].to_s.strip

    new_image_url = uploaded_url.presence || custom_url.presence

    if new_image_url.present? && @resource.update(image_url: new_image_url)
      respond_to do |format|
        format.html { redirect_to resource_path(@resource.slug), notice: "Изображение ресурса успешно обновлено." }
        format.json { render json: { image_url: @resource.image_url, message: "Изображение обновлено" } }
      end
    else
      respond_to do |format|
        format.html { redirect_to resource_path(@resource.slug), alert: "Выберите файл изображения или укажите корректный URL." }
        format.json { render json: { error: "Не удалось обновить изображение" }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_my_resource
    @resource = current_user.resources.find_by(slug: params[:id]) || current_user.resources.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to my_resources_path, alert: "Объявление не найдено или у вас нет прав на его изменение." }
      format.json { render json: { error: "У вас нет прав на изменение этого ресурса" }, status: :forbidden }
    end
  end

  def resource_params
    params.require(:resource).permit(
      :name,
      :category,
      :description,
      :location,
      :capacity,
      :hourly_rate,
      :rate_unit,
      :image_url
    )
  end

  # Сохранение загруженного пользователем файла в public/uploads
  def store_uploaded_image(uploaded_io, base64_data = nil)
    uploads_dir = Rails.root.join("public", "uploads")
    FileUtils.mkdir_p(uploads_dir)

    if base64_data.present? && base64_data.start_with?("data:image/")
      match = base64_data.match(/\Adata:image\/([a-zA-Z0-9+]+);base64,(.+)\z/m)
      if match
        ext = match[1] == "jpeg" ? "jpg" : match[1]
        raw_data = Base64.decode64(match[2])
        filename = "resource_#{Time.now.to_i}_#{rand(1000..9999)}.#{ext}"
        File.binwrite(uploads_dir.join(filename), raw_data)
        return "/uploads/#{filename}"
      end
      return base64_data
    elsif uploaded_io.respond_to?(:original_filename) && uploaded_io.respond_to?(:read)
      ext = File.extname(uploaded_io.original_filename).presence || ".jpg"
      filename = "resource_#{Time.now.to_i}_#{rand(1000..9999)}#{ext}"
      File.binwrite(uploads_dir.join(filename), uploaded_io.read)
      return "/uploads/#{filename}"
    end

    nil
  end
end
