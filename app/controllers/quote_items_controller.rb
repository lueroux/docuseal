# frozen_string_literal: true

class QuoteItemsController < ApplicationController
  before_action :set_quote
  before_action :set_quote_item, only: %i[update destroy]
  authorize_resource :quote

  def create
    @quote_item = @quote.quote_items.build(quote_item_params)
    
    if @quote_item.save
      @quote.update(total_price: @quote.calculate_total)
      
      respond_to do |format|
        format.html { redirect_to edit_quote_path(@quote), notice: 'Product added to quote.' }
        format.json { render json: { success: true, quote_item: @quote_item, total: @quote.total_price } }
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_quote_path(@quote), alert: @quote_item.errors.full_messages.join(', ') }
        format.json { render json: { errors: @quote_item.errors }, status: :unprocessable_content }
      end
    end
  end

  def update
    if @quote_item.update(quote_item_params)
      @quote.update(total_price: @quote.calculate_total)
      
      respond_to do |format|
        format.html { redirect_to edit_quote_path(@quote), notice: 'Item updated.' }
        format.json { render json: { success: true, quote_item: @quote_item, total: @quote.total_price } }
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_quote_path(@quote), alert: @quote_item.errors.full_messages.join(', ') }
        format.json { render json: { errors: @quote_item.errors }, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @quote_item.destroy
    @quote.update(total_price: @quote.calculate_total)
    
    respond_to do |format|
      format.html { redirect_to edit_quote_path(@quote), notice: 'Item removed from quote.' }
      format.json { render json: { success: true, total: @quote.total_price } }
    end
  end

  private

  def set_quote
    @quote = Quote.find(params[:quote_id])
  end

  def set_quote_item
    @quote_item = @quote.quote_items.find(params[:id])
  end

  def quote_item_params
    params.require(:quote_item).permit(
      :product_id,
      :quantity,
      :quoted_price,
      :discount_percentage,
      :notes
    )
  end
end
