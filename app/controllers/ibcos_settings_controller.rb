# frozen_string_literal: true

class IbcosSettingsController < ApplicationController
  before_action :load_encrypted_config
  authorize_resource :encrypted_config, only: :index
  authorize_resource :encrypted_config, parent: false, only: :create

  def index; end

  def create
    if @encrypted_config.update(ibcos_config_params)
      redirect_to settings_ibcos_path, notice: 'IBCOS Gold settings have been saved.'
    else
      render :index, status: :unprocessable_content
    end
  rescue StandardError => e
    flash[:alert] = e.message
    render :index, status: :unprocessable_content
  end

  def sync
    begin
      # Run synchronously to avoid Sidekiq dependency
      IbcosXmlSyncJob.perform_now(reschedule: false)
      redirect_to settings_ibcos_path, notice: 'IBCOS XML sync completed successfully!'
    rescue StandardError => e
      Rails.logger.error "IBCOS sync controller error: #{e.message}\n#{e.backtrace.join("\n")}"
      redirect_to settings_ibcos_path, alert: "Sync failed: #{e.message}"
    end
  end

  private

  def load_encrypted_config
    @encrypted_config =
      EncryptedConfig.find_or_initialize_by(account: current_account, key: EncryptedConfig::IBCOS_GOLD_KEY)
  end

  def ibcos_config_params
    params.require(:encrypted_config).permit(value: {}).tap do |p|
      p[:value].compact_blank!
    end
  end
end
