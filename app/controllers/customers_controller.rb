# frozen_string_literal: true

class CustomersController < ApplicationController
  authorize_resource
  before_action :set_customer, only: %i[show edit update destroy]

  def index
    @customers = current_account.customers.includes(:company).ordered
  end

  def show
    @pricing_terms = @customer.customer_pricing_terms
  end

  def new
    @customer = current_account.customers.new
    @companies = current_account.companies.ordered
  end

  def edit
    @companies = current_account.companies.ordered
  end

  def create
    @customer = current_account.customers.new(customer_params)

    if @customer.save
      redirect_to customers_path, notice: 'Customer created.'
    else
      @companies = current_account.companies.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @customer.update(customer_params)
      redirect_to customer_path(@customer), notice: 'Customer updated.'
    else
      @companies = current_account.companies.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path, notice: 'Customer deleted.'
  end

  private

  def set_customer
    @customer = current_account.customers.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :email, :phone, :company_id, :notes,
                                     billing_address: %i[line1 line2 city county postcode country],
                                     shipping_address: %i[line1 line2 city county postcode country])
  end
end
