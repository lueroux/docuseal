# frozen_string_literal: true

class IbcosXmlSyncJob < ApplicationJob
  queue_as :default

  def perform(reschedule: true)
    Rails.logger.info 'Starting IBCOS XML sync...'
    
    xml_url = 'https://buxtons.net/goldxml/parts.xml'
    storage_path = Rails.root.join('tmp', 'ibcos_parts.xml')
    
    begin
      # Download XML file
      response = Faraday.get(xml_url) do |req|
        req.options.timeout = 60
        req.options.open_timeout = 10
      end
      
      if response.success?
        # Ensure tmp directory exists
        FileUtils.mkdir_p(File.dirname(storage_path))
        
        # Save XML to file
        File.write(storage_path, response.body)
        
        # Update last sync timestamp (global, not account-specific)
        config = EncryptedConfig.where(key: 'ibcos_xml_sync').first_or_initialize
        config.account_id ||= Account.first&.id # Use first account if none set
        config.value = {
          last_sync: Time.current.iso8601,
          file_size: response.body.bytesize,
          status: 'success'
        }
        config.save!
        
        Rails.logger.info "IBCOS XML sync completed. File size: #{response.body.bytesize} bytes"
      else
        raise "HTTP #{response.status}: #{response.reason_phrase}"
      end
    rescue StandardError => e
      Rails.logger.error "IBCOS XML sync failed: #{e.message}"
      
      # Update sync status with error
      config = EncryptedConfig.where(key: 'ibcos_xml_sync').first_or_initialize
      config.account_id ||= Account.first&.id
      config.value = {
        last_sync: Time.current.iso8601,
        status: 'error',
        error: e.message
      }
      config.save!
      
      raise e
    ensure
      # Schedule next sync in 2 hours (only if reschedule is true)
      if reschedule
        IbcosXmlSyncJob.set(wait: 2.hours).perform_later(reschedule: true)
      end
    end
  end
end
