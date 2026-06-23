# frozen_string_literal: true

class IbcosSearchController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[index]
  before_action :authenticate_user!

  def index
    results = if params[:q].present?
                IbcosGoldService.search_parts(expression: params[:q], max_results: params[:limit] || 25)
              else
                []
              end

    render json: { results: }
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
          description: result[:name] # Use name as description for now
        }
      }
    else
      render json: { found: false }
    end
  end
end
