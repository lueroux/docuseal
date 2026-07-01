# frozen_string_literal: true

class ProductDocumentsController < ApplicationController
  before_action :set_product
  before_action :set_product_document, only: [:destroy]
  authorize_resource :product

  def index
    @product_documents = @product.product_documents.ordered
  end

  def create
    @product_document = @product.product_documents.new(product_document_params)

    if @product_document.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append('product_documents_list',
                                partial: 'product_documents/document_card',
                                locals: { document: @product_document, product: @product }),
            turbo_stream.replace('document_upload_form',
                                 partial: 'product_documents/upload_form',
                                 locals: { product: @product })
          ]
        end
        format.html { redirect_back fallback_location: edit_product_path(@product), notice: 'Document uploaded.' }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            'document_upload_form',
            partial: 'product_documents/upload_form',
            locals: { product: @product, errors: @product_document.errors }
          )
        end
        format.html { redirect_back fallback_location: edit_product_path(@product), alert: @product_document.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    @product_document.destroy

    respond_to do |format|
      format.turbo_stream do
        streams = [turbo_stream.remove("document_#{@product_document.id}")]
        if @product.product_documents.count.zero?
          streams << turbo_stream.append('product_documents_list',
            '<div id="no_documents_notice" class="text-sm text-base-content/50 italic">No documents yet. Use the form below to upload files.</div>'.html_safe)
        end
        render turbo_stream: streams
      end
      format.html { redirect_back fallback_location: edit_product_path(@product), notice: 'Document removed.' }
    end
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def set_product_document
    @product_document = @product.product_documents.find(params[:id])
  end

  def product_document_params
    params.require(:product_document).permit(:name, :file, :sort_order)
  end
end
