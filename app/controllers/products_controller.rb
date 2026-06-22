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
      spec_data: {},
      ibcos_data: {}
    )
  end
end
