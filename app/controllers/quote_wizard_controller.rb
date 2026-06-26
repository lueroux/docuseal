# frozen_string_literal: true

class QuoteWizardController < ApplicationController
  before_action :set_quote
  before_action :set_wizard_data
  authorize_resource :quote

  STEPS = %w[customer products options pricing attachments review].freeze
  PAYMENT_STRUCTURE_CONFIG = {
    'cash' => {
      title: 'Cash Price',
      description: 'One-off payment with optional deposit deduction.'
    },
    'finance' => {
      title: 'Finance Plan',
      description: 'Monthly finance example showing deposit, APR and provider.'
    },
    'lease' => {
      title: 'Lease Option',
      description: 'Operating lease details with monthly rental and term.'
    }
  }.freeze

  helper_method :payment_structure_configs

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
      @payment_structures = @quote.quote_payment_structures.order(:payment_type, :created_at)
    when 'attachments'
      @quote_attachments = @quote.quote_attachments.ordered
    when 'review'
      @quote_items = @quote.quote_items.includes(:product, :quote_item_options).ordered
      @payment_structures = @quote.quote_payment_structures.order(:payment_type, :created_at)
      @quote_attachments = @quote.quote_attachments.ordered
      @compatibility_issues = check_quote_compatibility
    end

    render "quote_wizard/#{@step}"
  end

  def add_payment_structure
    @payment_structure = @quote.quote_payment_structures.new(payment_structure_params)

    respond_to do |format|
      if @payment_structure.save
        format.turbo_stream { render_payment_structure_stream(@payment_structure.payment_type) }
        format.html { redirect_back fallback_location: quote_wizard_path(@quote, step: 'pricing'), notice: 'Payment option saved.' }
      else
        format.turbo_stream { render_payment_structure_form_with_errors(@payment_structure) }
        format.html do
          redirect_back fallback_location: quote_wizard_path(@quote, step: 'pricing'), alert: @payment_structure.errors.full_messages.to_sentence
        end
      end
    end
  end

  def update_payment_structure
    @payment_structure = @quote.quote_payment_structures.find(params[:structure_id])

    respond_to do |format|
      if @payment_structure.update(payment_structure_params)
        format.turbo_stream { render_payment_structure_stream(@payment_structure.payment_type) }
        format.html { redirect_back fallback_location: quote_wizard_path(@quote, step: 'pricing'), notice: 'Payment option updated.' }
      else
        format.turbo_stream { render_payment_structure_form_with_errors(@payment_structure) }
        format.html do
          redirect_back fallback_location: quote_wizard_path(@quote, step: 'pricing'), alert: @payment_structure.errors.full_messages.to_sentence
        end
      end
    end
  end

  def remove_payment_structure
    payment_structure = @quote.quote_payment_structures.find(params[:structure_id])
    payment_type = payment_structure.payment_type
    payment_structure.destroy

    respond_to do |format|
      format.turbo_stream { render_payment_structure_stream(payment_type) }
      format.html { redirect_back fallback_location: quote_wizard_path(@quote, step: 'pricing'), notice: 'Payment option removed.' }
    end
  end

  def upload_attachment
    @attachment = @quote.quote_attachments.build(attachment_params)

    respond_to do |format|
      if @attachment.save
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove('no_attachments_notice'),
            turbo_stream.append('quote_attachments_list',
                                partial: 'quote_wizard/attachment_card',
                                locals: { attachment: @attachment, quote: @quote }),
            turbo_stream.replace('attachment_upload_form',
                                 partial: 'quote_wizard/attachment_upload_form',
                                 locals: { quote: @quote })
          ]
        end
        format.html { redirect_back fallback_location: quote_wizard_path(@quote, step: 'attachments'), notice: 'File uploaded.' }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            'attachment_upload_form',
            partial: 'quote_wizard/attachment_upload_form',
            locals: { quote: @quote, errors: @attachment.errors.full_messages }
          )
        end
        format.html { redirect_back fallback_location: quote_wizard_path(@quote, step: 'attachments'), alert: @attachment.errors.full_messages.to_sentence }
      end
    end
  end

  def remove_attachment
    attachment = @quote.quote_attachments.find(params[:attachment_id])
    attachment.destroy

    respond_to do |format|
      format.turbo_stream do
        streams = [turbo_stream.remove("attachment_#{attachment.id}")]
        if @quote.quote_attachments.count.zero?
          streams << turbo_stream.append('quote_attachments_list',
            '<div id="no_attachments_notice" class="text-sm text-base-content/50 italic">No attachments yet. Use the form below to upload files.</div>'.html_safe)
        end
        render turbo_stream: streams
      end
      format.html { redirect_back fallback_location: quote_wizard_path(@quote, step: 'attachments'), notice: 'Attachment removed.' }
    end
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
    # Handle JSON body params
    if request.content_type == 'application/json'
      body_params = JSON.parse(request.body.read)
      product_id = body_params['product_id']
      quantity = body_params['quantity'] || 1
    else
      product_id = params[:product_id]
      quantity = params[:quantity] || 1
    end
    
    product = Product.find(product_id)
    
    @quote_item = @quote.quote_items.build(
      product: product,
      quantity: quantity,
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
          streams = []
          
          # If this is the first item, remove empty state and update container class
          if @quote.quote_items.count == 1
            streams << turbo_stream.remove('empty_state')
            streams << turbo_stream.update('quote_items_list', html: '', attributes: { class: 'space-y-3' })
            streams << turbo_stream.update('quote_total_container', html: '', attributes: { class: 'mt-6 flex justify-end' })
          end
          
          streams << turbo_stream.append('quote_items_list', partial: 'quote_wizard/quote_item', locals: { quote_item: @quote_item })
          streams << turbo_stream.replace('quote_total', partial: 'quote_wizard/quote_total', locals: { quote: @quote })
          
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
    
    if params[:quote_item][:option_ids].present?
      sync_quote_item_options(@quote_item, params[:quote_item][:option_ids])
    end

    if @quote_item.update(quote_item_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("quote_item_#{@quote_item.id}", partial: 'quote_wizard/quote_item', locals: { quote_item: @quote_item }),
            turbo_stream.replace('quote_total', partial: 'quote_wizard/quote_total', locals: { quote: @quote })
          ]
        end
        format.json { render json: { success: true, quote_item: @quote_item } }
        format.html { redirect_back fallback_location: quote_wizard_path(@quote, step: 'options'), notice: 'Options updated.' }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('form_errors', partial: 'shared/errors', locals: { object: @quote_item })
        end
        format.json { render json: { errors: @quote_item.errors }, status: :unprocessable_content }
        format.html { redirect_back fallback_location: quote_wizard_path(@quote, step: 'options'), alert: @quote_item.errors.full_messages.to_sentence }
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

  def update_option_price
    @quote_item_option = QuoteItemOption.find(params[:option_id])
    
    if @quote_item_option.update(option_price: params[:quote_item_option][:option_price])
      respond_to do |format|
        format.turbo_stream do
          quote_item = @quote_item_option.quote_item
          render turbo_stream: [
            turbo_stream.replace("quote_item_#{quote_item.id}", partial: 'quote_wizard/quote_item', locals: { quote_item: quote_item }),
            turbo_stream.replace('quote_total', partial: 'quote_wizard/quote_total', locals: { quote: @quote })
          ]
        end
        format.json { render json: { success: true } }
      end
    else
      render json: { errors: @quote_item_option.errors.full_messages }, status: :unprocessable_content
    end
  end

  def finalize
    # Fetch latest product data from WooCommerce before finalizing
    sync_products_with_woocommerce

    issues = check_quote_compatibility
    blocking = issues.select { |i| i[:type] == 'requires' }

    if blocking.any?
      @compatibility_issues = issues
      @quote_items = @quote.quote_items.includes(:product, :quote_item_options).ordered
      @payment_structures = @quote.quote_payment_structures.order(:payment_type, :created_at)
      @quote_attachments = @quote.quote_attachments.ordered
      flash.now[:alert] = 'Please resolve compatibility issues before finalizing.'
      render 'quote_wizard/review', status: :unprocessable_content
      return
    end

    # Auto-remove excluded items
    remove_excluded_items

    @quote.update!(status: 'draft', total_price: @quote.calculate_total)

    if @quote.customer&.email.present?
      begin
        submission = QuoteSigningService.new(@quote, current_user).send_for_signing!
        redirect_to @quote, notice: "Quote finalised and sent to #{@quote.customer.email} for signing!"
      rescue => e
        Rails.logger.error("Failed to send quote for signing: #{e.message}")
        redirect_to @quote, alert: "Quote saved but signing request failed: #{e.message}. You can send it from the quote page."
      end
    else
      redirect_to @quote, notice: 'Quote finalised. Add a customer to send for signing.'
    end
  end

  def send_for_signing
    unless @quote.customer&.email.present?
      redirect_to quote_wizard_path(@quote, step: 'customer'), alert: 'Please select a customer first.'
      return
    end

    unless @quote.quote_items.any?
      redirect_to quote_wizard_path(@quote, step: 'products'), alert: 'Please add products first.'
      return
    end

    begin
      submission = QuoteSigningService.new(@quote, current_user).send_for_signing!
      redirect_to @quote, notice: "Quote sent to #{@quote.customer.email} for signing!"
    rescue => e
      Rails.logger.error("Failed to send quote for signing: #{e.message}")
      redirect_to @quote, alert: "Failed to send: #{e.message}"
    end
  end
  end

  private

  def sync_products_with_woocommerce
    return unless WoocommerceProductSync.new(@quote.account).configured?

    @quote.quote_items.includes(:product).find_each do |quote_item|
      product = quote_item.product
      next unless product

      WoocommerceProductSync.new(@quote.account).sync_product!(product.sku)
    end
  end

  def set_quote
    if params[:id]
      @quote = Quote.find(params[:id])
    else
      # Visiting /quotes/new — always start fresh, clear stale draft
      session.delete(:draft_quote_id)
      @quote = Quote.new(
        account: current_account,
        user: current_user,
        status: 'draft'
      )
      @quote.send(:generate_reference_number) if @quote.reference_number.blank?
      @quote.save(validate: false)
      session[:draft_quote_id] = @quote.id
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

  def check_quote_compatibility
    issues = []
    @quote.quote_items.includes(:product).each do |item|
      issues.concat(check_compatibility(item))
    end
    issues.uniq { |i| [i[:type], i[:sku]] }
  end

  def remove_excluded_items
    @quote.quote_items.includes(:product).each do |item|
      item.product.product_compatibility_rules.excludes.each do |rule|
        excluded = @quote.quote_items.joins(:product).find_by(products: { sku: rule.result_action })
        excluded&.destroy
      end
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
      @product_options[item.id] = item.product.product_options.includes(:linked_product).order(:sort_order)
    end
  end

  def sync_quote_item_options(quote_item, option_ids)
    option_ids = Array(option_ids).map(&:to_i)
    
    # Always keep required options selected
    quote_item.product.product_options.where(is_required: true).each do |req_opt|
      option_ids << req_opt.id unless option_ids.include?(req_opt.id)
    end

    # Auto-include all non-customer-choice options (they're always on)
    quote_item.product.product_options.where(customer_choice: false).each do |auto_opt|
      option_ids << auto_opt.id unless option_ids.include?(auto_opt.id)
    end
    
    # Remove unselected options (except required + auto-included ones)
    quote_item.quote_item_options.where.not(product_option_id: option_ids).destroy_all
    
    # Add newly selected options
    option_ids.each do |option_id|
      option = quote_item.product.product_options.find_by(id: option_id)
      next unless option
      
      quote_item.quote_item_options.find_or_create_by!(product_option_id: option_id) do |qio|
        qio.name = option.name
        qio.price = option.price
        qio.is_selected = true
      end
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

  def attachment_params
    params.require(:quote_attachment).permit(:name, :description, :file)
  end

  def quote_item_params
    params.require(:quote_item).permit(
      :quantity,
      :quoted_price,
      :discount_percentage,
      :notes
    )
  end

  def payment_structure_params
    params.require(:quote_payment_structure).permit(
      :payment_type,
      :term_months,
      :deposit,
      :monthly_payment,
      :total_cost,
      :apr,
      :provider,
      :is_primary
    )
  end

  def render_payment_structure_stream(payment_type)
    structure = @quote.quote_payment_structures.find_by(payment_type:) ||
                @quote.quote_payment_structures.build(payment_type:)

    render turbo_stream: turbo_stream.replace(
      "payment_structure_#{payment_type}",
      partial: 'quote_wizard/payment_structure_card',
      locals: {
        quote: @quote,
        structure: structure,
        config: payment_structure_configs[payment_type],
        form_errors: nil
      }
    )
  end

  def render_payment_structure_form_with_errors(structure)
    payment_type = structure.payment_type || payment_structure_params[:payment_type]

    render turbo_stream: turbo_stream.replace(
      "payment_structure_#{payment_type}",
      partial: 'quote_wizard/payment_structure_card',
      locals: {
        quote: @quote,
        structure: structure,
        config: payment_structure_configs[payment_type],
        form_errors: structure.errors.full_messages
      }
    )
  end

  def payment_structure_configs
    PAYMENT_STRUCTURE_CONFIG
  end
end
