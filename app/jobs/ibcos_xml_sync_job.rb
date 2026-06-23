# frozen_string_literal: true

class IbcosXmlSyncJob < ApplicationJob
  queue_as :default

  def perform(reschedule: true)
    Rails.logger.info 'Starting IBCOS XML sync...'
    
    xml_url = 'https://buxtons.net/goldxml/parts.xml'
    # Use /data for persistent storage across deployments
    storage_path = Rails.env.production? ? Pathname.new('/data/docuseal/ibcos_parts.xml') : Rails.root.join('tmp', 'ibcos_parts.xml')
    
    begin
      # Download XML file with headers to bypass Cloudflare
      # Note: Faraday automatically handles gzip decompression
      response = Faraday.get(xml_url) do |req|
        req.options.timeout = 60
        req.options.open_timeout = 10
        req.headers['User-Agent'] = 'Buxtons-Quote-Tool/1.0 (Rails; +https://docuseal-railway-production-38a4.up.railway.app)'
        req.headers['Accept'] = 'application/xml, text/xml, */*'
        req.headers['Connection'] = 'keep-alive'
      end
      
      if response.success?
        # Ensure tmp directory exists
        FileUtils.mkdir_p(File.dirname(storage_path))
        
        # Save XML to file
        File.write(storage_path, response.body)
        
        # Count parts in XML
        doc = Nokogiri::XML(response.body)
        parts_count = doc.xpath('//part | //Part').count
        
        # Update last sync timestamp (global, not account-specific)
        config = EncryptedConfig.where(key: 'ibcos_xml_sync').first_or_initialize
        config.account_id ||= Account.first&.id # Use first account if none set
        config.value = {
          last_sync: Time.current.iso8601,
          file_size: response.body.bytesize,
          parts_count: parts_count,
          status: 'success'
        }
        config.save!
        
        # Clear all IBCOS caches to force fresh data load
        Rails.cache.delete_matched('ibcos:*')
        
        Rails.logger.info "IBCOS XML sync completed. File size: #{response.body.bytesize} bytes, Parts: #{parts_count}"
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
