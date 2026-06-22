# frozen_string_literal: true

module Portal
  class SessionsController < ApplicationController
    skip_before_action :authenticate_user!
    skip_authorization_check
    layout 'portal'

    def new
      # Magic-link request form — customer enters their email
    end

    def create
      customer = Customer.find_by(email: params[:email].to_s.strip.downcase)

      if customer
        customer.generate_portal_token!
        PortalMailer.magic_link(customer).deliver_later
      end

      # Always show the same message to prevent email enumeration
      redirect_to portal_login_path, notice: 'If that email is registered, a sign-in link has been sent.'
    end

    def show
      customer = Customer.find_by(portal_token: params[:token])

      if customer&.portal_token_valid?
        session[:portal_customer_id] = customer.id
        customer.invalidate_portal_token!
        redirect_to portal_root_path, notice: 'Signed in successfully.'
      else
        redirect_to portal_login_path, alert: 'This link is invalid or has expired. Please request a new one.'
      end
    end

    def destroy
      session.delete(:portal_customer_id)
      redirect_to portal_login_path, notice: 'Signed out.'
    end
  end
end
