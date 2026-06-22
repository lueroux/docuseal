# frozen_string_literal: true

class CompaniesController < ApplicationController
  authorize_resource
  before_action :set_company, only: %i[show edit update destroy]

  def index
    @companies = current_account.companies.ordered
  end

  def show
    @customers = @company.customers.ordered
  end

  def new
    @company = current_account.companies.new
  end

  def edit; end

  def create
    @company = current_account.companies.new(company_params)

    if @company.save
      redirect_to companies_path, notice: 'Company created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @company.update(company_params)
      redirect_to company_path(@company), notice: 'Company updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @company.destroy
    redirect_to companies_path, notice: 'Company deleted.'
  end

  private

  def set_company
    @company = current_account.companies.find(params[:id])
  end

  def company_params
    params.require(:company).permit(:name, :email, :phone, :notes,
                                    billing_address: %i[line1 line2 city county postcode country],
                                    shipping_address: %i[line1 line2 city county postcode country])
  end
end
