# frozen_string_literal: true

class ProductsController < ApplicationController
  authorize_resource
  before_action :set_product, only: %i[show edit update destroy]

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
      redirect_to @product, notice: 'Product was successfully created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: 'Product was successfully updated.'
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
      redirect_to @product, notice: 'Product synced from WooCommerce successfully.'
    else
      redirect_to @product, alert: "Sync failed: #{result[:error]}"
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
      :retail_price,
      :cost_price,
      :markup_percentage,
      :available,
      :woocommerce_product_id,
      :image_url,
      spec_data: {},
      ibcos_data: {},
      manual_edit_flags: {}
    )
  end
end
