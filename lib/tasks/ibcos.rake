# frozen_string_literal: true

namespace :ibcos do
  desc 'Sync IBCOS parts XML file from buxtons.net'
  task sync_xml: :environment do
    puts 'Starting IBCOS XML sync...'
    
    begin
      IbcosXmlSyncJob.perform_now
      puts 'IBCOS XML sync completed successfully!'
      
      if IbcosGoldService.xml_file_exists?
        age = IbcosGoldService.xml_file_age
        puts "XML file age: #{age.to_i} seconds"
      end
    rescue StandardError => e
      puts "IBCOS XML sync failed: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end
  
  desc 'Check IBCOS XML file status'
  task status: :environment do
    if IbcosGoldService.xml_file_exists?
      age = IbcosGoldService.xml_file_age
      puts "✓ IBCOS XML file exists"
      puts "  Path: #{IbcosGoldService::XML_FILE_PATH}"
      puts "  Age: #{age.to_i} seconds (#{(age / 3600).round(1)} hours)"
      puts "  Size: #{File.size(IbcosGoldService::XML_FILE_PATH)} bytes"
      
      config = EncryptedConfig.find_by(key: 'ibcos_xml_sync')
      if config
        puts "  Last sync: #{config.value['last_sync']}"
        puts "  Status: #{config.value['status']}"
      end
    else
      puts "✗ IBCOS XML file not found"
      puts "  Expected path: #{IbcosGoldService::XML_FILE_PATH}"
      puts "  Run 'rake ibcos:sync_xml' to download"
    end
  end
end
