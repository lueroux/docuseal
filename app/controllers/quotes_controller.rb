# frozen_string_literal: true

class QuotesController < ApplicationController
  before_action :set_quote, only: %i[show edit update destroy document]
  authorize_resource

  def index
    @pagy, @quotes = pagy(Quote.where(account: current_account).includes(:customer, :user).recent)
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        Rails.logger.info("Starting PDF generation for quote #{@quote.id}")
        begin
          pdf_generator = QuotePdfGenerator.new(@quote)
          Rails.logger.info("QuotePdfGenerator initialized")
          pdf_data = pdf_generator.generate
          Rails.logger.info("PDF generated successfully, size: #{pdf_data.bytesize}")
          send_data pdf_data,
                    filename: "quote-#{@quote.reference_number}.pdf",
                    type: 'application/pdf',
                    disposition: 'inline'
        rescue => e
          Rails.logger.error("PDF generation failed: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          render plain: "PDF generation failed: #{e.message}", status: :internal_server_error
        end
      end
    end
  end

  def document
    @document_html = QuoteDocumentBuilder.new(@quote).build_html
    render layout: 'quote_document'
  end

  def new
    @quote = Quote.new(account: current_account, user: current_user)
    @customers = Customer.where(account: current_account).ordered
    @products = Product.where(account: current_account).available
  end

  def create
    @quote = Quote.new(quote_params)
    @quote.account = current_account
    @quote.user = current_user

    if @quote.save
      redirect_to edit_quote_path(@quote), notice: 'Quote created successfully.'
    else
      @customers = Customer.where(account: current_account).ordered
      @products = Product.where(account: current_account).available
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @quote = Quote.includes(quote_items: :product).find(params[:id])
    @customers = Customer.where(account: current_account).ordered
    @products = Product.where(account: current_account).available
  end

  def update
    if @quote.update(quote_params)
      respond_to do |format|
        format.html { redirect_to @quote, notice: 'Quote updated successfully.' }
        format.json { render json: { success: true, quote: @quote } }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: { errors: @quote.errors }, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @quote.destroy
    redirect_to quotes_path, notice: 'Quote deleted successfully.'
  end

  private

  def set_quote
    @quote = Quote.find(params[:id])
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
end
