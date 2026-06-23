# frozen_string_literal: true

module Ibcos
  class SearchController < ApplicationController
    skip_before_action :verify_authenticity_token, only: %i[index quick]
    skip_authorization_check
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
      Rails.logger.info "IBCOS quick search request: part_no=#{params[:part_no]}"
      
      unless params[:part_no].present?
        Rails.logger.warn "No part_no provided"
        return render json: { found: false, error: 'No part number provided' }
      end

      Rails.logger.info "Calling IbcosGoldService.quick_part_search..."
      result = IbcosGoldService.quick_part_search(part_no: params[:part_no])
      Rails.logger.info "Search result: #{result.inspect}"

      if result
        render json: { 
          found: true, 
          product: {
            name: result[:name],
            brand: result[:brand],
            category: result[:category],
            retail_price: format_price(result[:retail_price]),
            cost_price: format_price(result[:cost_price]),
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

    private

    def format_price(price)
      return nil if price.nil?
      
      number_with_precision(price, precision: 2, delimiter: ',')
    end
  end
end
