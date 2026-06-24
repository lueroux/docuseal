# frozen_string_literal: true

class WoocommerceSettingsController < ApplicationController
  authorize_resource class: false
  before_action :set_configs

  def show; end

  def update
    update_config('woocommerce_url', params[:woocommerce_url])
    update_config('woocommerce_consumer_key', params[:woocommerce_consumer_key])
    update_config('woocommerce_consumer_secret', params[:woocommerce_consumer_secret])

    redirect_to settings_woocommerce_path, notice: 'WooCommerce settings updated successfully.'
  end

  def test_connection
    sync_service = WoocommerceProductSync.new(current_account)

    if sync_service.configured?
      # Try to fetch a product to test connection
      test_result = sync_service.fetch_by_sku('TEST')
      if test_result || test_result.nil? # nil means API responded but product not found
        redirect_to settings_woocommerce_path, notice: 'Connection successful!'
      else
        redirect_to settings_woocommerce_path, alert: 'Connection failed. Please check your credentials.'
      end
    else
      redirect_to settings_woocommerce_path, alert: 'Please configure WooCommerce URL and credentials first.'
    end
  end

  private

  def set_configs
    @woo_url = EncryptedConfig.find_by(account: current_account, key: 'woocommerce_url')&.value
    @woo_consumer_key = EncryptedConfig.find_by(account: current_account, key: 'woocommerce_consumer_key')&.value
    @woo_consumer_secret = EncryptedConfig.find_by(account: current_account, key: 'woocommerce_consumer_secret')&.value
  end

  def update_config(key, value)
    config = EncryptedConfig.find_or_initialize_by(account: current_account, key:)
    config.value = value.presence
    config.save
  end
end
