# frozen_string_literal: true

module PortalAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_portal_customer
  end

  private

  def current_portal_customer
    @current_portal_customer ||= begin
      id = session[:portal_customer_id]
      Customer.find_by(id:) if id
    end
  end
end
