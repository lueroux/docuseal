# frozen_string_literal: true

class ProductsController < ApplicationController
  authorize_resource
  before_action :set_product, only: %i[show edit update destroy sync]

  def index
    @products = current_account.products.order(:brand, :name)
    @products = @products.where(available: true) if params[:available].present?
    @products = @products.by_brand(params[:brand]) if params[:brand].present?
    @products = @products.by_category(params[:category]) if params[:category].present?
  end

  def show; end

  def new
    @product = current_account.products.build
  end

  def edit; end

  def create
    @product = current_account.products.build(product_params)

    if @product.save
      redirect_to @product, notice: 'Product was successfully created.', allow_other_host: true
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: 'Product was successfully updated.', allow_other_host: true
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path, notice: 'Product was successfully deleted.'
  end

  def sync
    sync_service = WoocommerceProductSync.new(current_account)
    result = sync_service.sync_product!(@product.sku)

    if result[:success]
      redirect_to @product, notice: 'Product synced from WooCommerce successfully.', allow_other_host: true
    else
      redirect_to @product, alert: "Sync failed: #{result[:error]}", allow_other_host: true
    end
  end

  def sync_all
    sync_service = WoocommerceProductSync.new(current_account)
    results = sync_service.sync_all!

    if results[:failed].zero?
      redirect_to products_path, notice: "All #{results[:synced]} products synced successfully."
    else
      redirect_to products_path, alert: "Synced #{results[:synced]} products, #{results[:failed]} failed."
    end
  end

  private

  def set_product
    @product = current_account.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :sku,
      :name,
      :brand,
      :category,
      :description,
      :short_description,
      :retail_price,
      :cost_price,
      :markup_percentage,
      :available,
      :woocommerce_product_id,
      :image_url,
      :stock_status,
      :weight,
      :dimensions,
      :dimensions_length,
      :dimensions_width,
      :dimensions_height,
      :permalink,
      :date_on_sale_from,
      :date_on_sale_to,
      :sale_price,
      :regular_price,
      :manage_stock,
      :stock_quantity,
      :backorders,
      :sold_individually,
      :virtual,
      :downloadable,
      :tax_class,
      :tax_status,
      :shipping_class,
      :external_url,
      :button_text,
      :menu_order,
      :reviews_allowed,
      :average_rating,
      :rating_count,
      :total_sales,
      spec_data: {},
      ibcos_data: {},
      woo_attributes: {},
      attribute_visibility: {},
      manual_edit_flags: {}
    )
  end
end
