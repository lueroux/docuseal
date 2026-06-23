# frozen_string_literal: true

class IbcosSearchController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[index quick]
  before_action :authenticate_user!

  def index
    results = if params[:q].present?
                IbcosGoldService.search_parts(expression: params[:q], max_results: params[:limit] || 25)
              else
                []
              end

    render json: { results: }
  rescue StandardError => e
    Rails.logger.error "IBCOS search error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  def quick
    result = if params[:part_no].present?
               IbcosGoldService.quick_part_search(part_no: params[:part_no])
             else
               nil
             end

    if result
      render json: { 
        found: true, 
        product: {
          name: result[:name],
          brand: result[:brand],
          category: result[:category],
          retail_price: result[:retail_price],
          cost_price: result[:cost_price],
          description: result[:name]
        }
      }
    else
      render json: { found: false }
    end
  rescue StandardError => e
    Rails.logger.error "IBCOS quick search error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end
end
