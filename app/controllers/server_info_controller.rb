# frozen_string_literal: true

class ServerInfoController < ApplicationController
  skip_authorization_check

  def index
    @server_info = {
      ip_addresses: fetch_ip_addresses,
      hostname: Socket.gethostname,
      rails_env: Rails.env,
      ruby_version: RUBY_VERSION,
      rails_version: Rails.version,
      user_agent: request.user_agent,
      server_time: Time.current,
      timezone: Time.zone.name
    }
  end

  private

  def fetch_ip_addresses
    ips = {}
    
    # External IP (what the internet sees)
    begin
      response = Faraday.get('https://api.ipify.org?format=json')
      ips[:external] = JSON.parse(response.body)['ip'] if response.success?
    rescue StandardError => e
      Rails.logger.error "Failed to fetch external IP: #{e.message}"
      ips[:external] = 'Unable to fetch'
    end
    
    # Local IPs
    begin
      Socket.ip_address_list.select(&:ipv4?).reject(&:ipv4_loopback?).each_with_index do |addr, i|
        ips["local_#{i + 1}".to_sym] = addr.ip_address
      end
    rescue StandardError => e
      Rails.logger.error "Failed to fetch local IPs: #{e.message}"
    end
    
    ips
  end
end
