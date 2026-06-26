# frozen_string_literal: true

class ProductOptionsController < ApplicationController
  authorize_resource
  before_action :set_product
  before_action :set_product_option, only: %i[destroy]

  def index
    @product_options = @product.product_options.ordered
  end

  def create
    @product_option = @product.product_options.build(product_option_params)

    if @product_option.save
      redirect_to edit_product_path(@product), notice: 'Product option was successfully added.'
    else
      redirect_to edit_product_path(@product), alert: @product_option.errors.full_messages.to_sentence
    end
  end

  def destroy
    @product_option.destroy
    redirect_to edit_product_path(@product), notice: 'Product option was successfully removed.'
  end

  private

  def set_product
    @product = current_account.products.find(params[:product_id])
  end

  def set_product_option
    @product_option = @product.product_options.find(params[:id])
  end

  def product_option_params
    params.require(:product_option).permit(
      :sku,
      :name,
      :description,
      :price,
      :is_required,
      :option_group,
      :option_type,
      :sort_order,
      :linked_product_id
    )
  end
end
