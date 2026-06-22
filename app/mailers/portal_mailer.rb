# frozen_string_literal: true

class PortalMailer < ApplicationMailer
  def magic_link(customer)
    @customer = customer
    @magic_link_url = portal_session_url(token: customer.portal_token)

    mail(to: customer.email, subject: 'Your Buxtons Quote Portal link')
  end
end
