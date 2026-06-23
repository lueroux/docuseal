# frozen_string_literal: true

class QuoteWizardController < ApplicationController
  before_action :set_quote
  before_action :set_wizard_data
  authorize_resource :quote

  STEPS = %w[customer products options pricing review].freeze

  def show
    @step = params[:step] || 'customer'
    redirect_to quote_wizard_path(@quote, step: 'customer') unless STEPS.include?(@step)

    case @step
    when 'customer'
      @customers = Customer.where(account: current_account).ordered
    when 'products'
      @products = Product.where(account: current_account).available.order(:name)
      @quote_items = @quote.quote_items.includes(:product, :quote_item_options).ordered
    when 'options'
      @quote_items = @quote.quote_items.includes(:product, :quote_item_options).ordered
      load_product_options
    when 'pricing'
      @quote_items = @quote.quote_items.includes(:product).ordered
    when 'review'
      @quote_items = @quote.quote_items.includes(:product, :quote_item_options).ordered
    end

    render "quote_wizard/#{@step}"
  end

  def update
    @step = params[:step] || 'customer'
    
    if @quote.update(quote_params)
      # Autosave successful
      respond_to do |format|
        format.html { redirect_to next_step_path }
        format.json { render json: { success: true, message: 'Saved' } }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            'autosave_status',
            partial: 'quote_wizard/autosave_status',
            locals: { saved: true }
          )
        end
      end
    else
      respond_to do |format|
        format.html { render "quote_wizard/#{@step}", status: :unprocessable_content }
        format.json { render json: { errors: @quote.errors }, status: :unprocessable_content }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            'autosave_status',
            partial: 'quote_wizard/autosave_status',
            locals: { saved: false, errors: @quote.errors }
          )
        end
      end
    end
  end

  def add_item
    product = Product.find(params[:product_id])
    
    @quote_item = @quote.quote_items.build(
      product: product,
      quantity: params[:quantity] || 1,
      cost_price: product.cost_price,
      retail_price: product.retail_price,
      quoted_price: product.retail_price,
      discount_percentage: 0
    )

    if @quote_item.save
      # Check compatibility
      compatibility_issues = check_compatibility(@quote_item)
      
      respond_to do |format|
        format.turbo_stream do
          streams = [
            turbo_stream.append('quote_items_list', partial: 'quote_wizard/quote_item', locals: { quote_item: @quote_item }),
            turbo_stream.replace('quote_total', partial: 'quote_wizard/quote_total', locals: { quote: @quote })
          ]
          
          if compatibility_issues.any?
            streams << turbo_stream.prepend('compatibility_alerts', partial: 'quote_wizard/compatibility_alert', locals: { issues: compatibility_issues })
          end
          
          render turbo_stream: streams
        end
        format.json { render json: { success: true, quote_item: @quote_item, compatibility_issues: compatibility_issues } }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('form_errors', partial: 'shared/errors', locals: { object: @quote_item })
        end
        format.json { render json: { errors: @quote_item.errors }, status: :unprocessable_content }
      end
    end
  end

  def update_item
    @quote_item = @quote.quote_items.find(params[:item_id])
    
    if @quote_item.update(quote_item_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("quote_item_#{@quote_item.id}", partial: 'quote_wizard/quote_item', locals: { quote_item: @quote_item }),
            turbo_stream.replace('quote_total', partial: 'quote_wizard/quote_total', locals: { quote: @quote })
          ]
        end
        format.json { render json: { success: true, quote_item: @quote_item } }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('form_errors', partial: 'shared/errors', locals: { object: @quote_item })
        end
        format.json { render json: { errors: @quote_item.errors }, status: :unprocessable_content }
      end
    end
  end

  def remove_item
    @quote_item = @quote.quote_items.find(params[:item_id])
    @quote_item.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("quote_item_#{@quote_item.id}"),
          turbo_stream.replace('quote_total', partial: 'quote_wizard/quote_total', locals: { quote: @quote })
        ]
      end
      format.json { render json: { success: true } }
    end
  end

  def finalize
    @quote.update!(status: 'draft', total_price: @quote.calculate_total)
    redirect_to @quote, notice: 'Quote created successfully!'
  end

  private

  def set_quote
    if params[:id]
      @quote = Quote.find(params[:id])
    else
      @quote = Quote.find_or_initialize_by(
        id: session[:draft_quote_id],
        account: current_account,
        user: current_user,
        status: 'draft'
      )
      
      unless @quote.persisted?
        @quote.save(validate: false)
        session[:draft_quote_id] = @quote.id
      end
    end
  end

  def set_wizard_data
    @current_step = params[:step] || 'customer'
    @step_index = STEPS.index(@current_step) || 0
    @progress_percentage = ((@step_index + 1).to_f / STEPS.length * 100).round
  end

  def next_step_path
    next_index = @step_index + 1
    if next_index < STEPS.length
      quote_wizard_path(@quote, step: STEPS[next_index])
    else
      finalize_quote_wizard_path(@quote)
    end
  end

  def check_compatibility(quote_item)
    issues = []
    product = quote_item.product
    existing_products = @quote.quote_items.where.not(id: quote_item.id).includes(:product)

    # Check requires rules
    product.product_compatibility_rules.requires.each do |rule|
      required_sku = rule.result_action
      unless existing_products.any? { |item| item.product.sku == required_sku }
        issues << {
          type: 'requires',
          message: "#{product.name} requires #{required_sku}",
          action: 'add',
          sku: required_sku
        }
      end
    end

    # Check excludes rules
    product.product_compatibility_rules.excludes.each do |rule|
      excluded_sku = rule.result_action
      if existing_products.any? { |item| item.product.sku == excluded_sku }
        issues << {
          type: 'excludes',
          message: "#{product.name} is not compatible with #{excluded_sku}",
          action: 'remove',
          sku: excluded_sku
        }
      end
    end

    # Check suggests rules
    product.product_compatibility_rules.suggests.each do |rule|
      suggested_sku = rule.result_action
      unless existing_products.any? { |item| item.product.sku == suggested_sku }
        issues << {
          type: 'suggests',
          message: "Consider adding #{suggested_sku} with #{product.name}",
          action: 'suggest',
          sku: suggested_sku
        }
      end
    end

    issues
  end

  def load_product_options
    @product_options = {}
    @quote.quote_items.each do |item|
      @product_options[item.id] = item.product.product_options.order(:sort_order)
    end
  end

  def quote_params
    params.require(:quote).permit(
      :customer_id,
      :title,
      :notes,
      :internal_notes,
      :valid_until,
      :status
    )
  end

  def quote_item_params
    params.require(:quote_item).permit(
      :quantity,
      :quoted_price,
      :discount_percentage,
      :notes
    )
  end
end
