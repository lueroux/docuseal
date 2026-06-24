# frozen_string_literal: true

class ProductCompatibilityRulesController < ApplicationController
  authorize_resource
  before_action :set_product
  before_action :set_product_compatibility_rule, only: %i[destroy]

  def index
    @product_compatibility_rules = @product.product_compatibility_rules
  end

  def create
    @rule = @product.product_compatibility_rules.build(rule_params)

    if @rule.save
      redirect_to product_path(@product), notice: 'Compatibility rule was successfully added.'
    else
      redirect_to product_path(@product), alert: @rule.errors.full_messages.to_sentence
    end
  end

  def destroy
    @rule.destroy
    redirect_to product_path(@product), notice: 'Compatibility rule was successfully removed.'
  end

  private

  def set_product
    @product = current_account.products.find(params[:product_id])
  end

  def set_product_compatibility_rule
    @rule = @product.product_compatibility_rules.find(params[:id])
  end

  def rule_params
    params.require(:product_compatibility_rule).permit(
      :rule_type,
      :condition_type,
      :condition_value,
      :result_action,
      :result_value
    )
  end
end
