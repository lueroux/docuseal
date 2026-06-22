# frozen_string_literal: true

module Portal
  class BaseController < ApplicationController
    include PortalAuthentication

    skip_before_action :authenticate_user!
    skip_authorization_check
    before_action :authenticate_customer!

    layout 'portal'

    private

    def authenticate_customer!
      return if current_portal_customer

      redirect_to portal_login_path, alert: 'Please sign in to access the portal.'
    end
  end
end
