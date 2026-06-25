# frozen_string_literal: true

class QuotesController < ApplicationController
  before_action :set_quote, only: %i[show edit update destroy document]
  authorize_resource

  def index
    @pagy, @quotes = pagy(Quote.where(account: current_account).includes(:customer, :user).recent)
  end

  def show
    Rails.logger.info("QuotesController#show called, format: #{request.format.symbol}")
    respond_to do |format|
      format.html
      format.pdf do
        Rails.logger.info("Starting PDF generation for quote #{@quote.id}")
        begin
          # Generate HTML using the same document builder as the view
          html = QuoteDocumentBuilder.new(@quote).build_html
          
          # Convert HTML to PDF using wkhtmltopdf
          pdf_data = WickedPdf.new.pdf_from_string(html, {
            page_size: 'A4',
            margin: { top: '0mm', bottom: '0mm', left: '0mm', right: '0mm' },
            print_media_type: true,
            no_images: false,
            encoding: 'UTF-8',
            javascript_delay: 0,
            disable_javascript: true
          })
          
          # Append attachment pages
          if @quote.quote_attachments.ordered.any?
            merger = QuotePdfAttachmentMerger.new(pdf_data, @quote)
            pdf_data = merger.merge
          end
          
          Rails.logger.info("PDF generated successfully, size: #{pdf_data.bytesize}")
          send_data pdf_data,
                    filename: "quote-#{@quote.reference_number}.pdf",
                    type: 'application/pdf',
                    disposition: 'inline'
        rescue => e
          Rails.logger.error("PDF generation failed: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
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
      redirect_to quote_wizard_path(@quote, step: 'customer'), notice: 'Quote created. Continue with the wizard.'
    else
      @customers = Customer.where(account: current_account).ordered
      @products = Product.where(account: current_account).available
      render :new, status: :unprocessable_content
    end
  end

  def edit
    redirect_to quote_wizard_path(params[:id], step: 'customer'), notice: 'Use the wizard to edit this quote.'
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
    Rails.logger.info("set_quote called with id: #{params[:id]}")
    @quote = Quote.find(params[:id])
    Rails.logger.info("set_quote found quote: #{@quote.id}")
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
