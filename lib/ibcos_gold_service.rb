# frozen_string_literal: true

class IbcosGoldService
  CACHE_TTL = 15.minutes
  XML_FILE_PATH = Rails.root.join('tmp', 'ibcos_parts.xml')

  def self.search_parts(expression:, max_results: 25)
    Rails.cache.fetch("ibcos:search:#{expression}:#{max_results}", expires_in: CACHE_TTL) do
      parts = load_all_parts
      
      # Filter parts by expression (case-insensitive search in SKU, name, brand, category)
      filtered = parts.select do |part|
        part[:sku]&.downcase&.include?(expression.downcase) ||
          part[:name]&.downcase&.include?(expression.downcase) ||
          part[:brand]&.downcase&.include?(expression.downcase) ||
          part[:category]&.downcase&.include?(expression.downcase)
      end
      
      filtered.take(max_results)
    end
  rescue StandardError => e
    Rails.logger.error "IBCOS search error: #{e.message}"
    []
  end

  def self.quick_part_search(part_no:)
    Rails.cache.fetch("ibcos:quick:#{part_no}", expires_in: CACHE_TTL) do
      Rails.logger.info "Loading parts for quick search..."
      parts = load_all_parts
      Rails.logger.info "Parts loaded: #{parts.size}"
      
      # Find exact match by SKU
      result = parts.find { |part| part[:sku]&.downcase == part_no.downcase }
      Rails.logger.info "Match found: #{result.present?}"
      result
    end
  rescue StandardError => e
    Rails.logger.error "IBCOS quick search error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    nil
  end

  def self.part_price(part_no:, customer_account:)
    # For now, just return the part's base pricing
    part = quick_part_search(part_no:)
    return nil unless part

    {
      retail_price: part[:retail_price],
      cost_price: part[:cost_price],
      discount_percentage: 0
    }
  rescue StandardError => e
    Rails.logger.error "IBCOS price error: #{e.message}"
    nil
  end

  def self.customer_info(customer_account:)
    # Not available in XML file
    Rails.logger.warn "Customer info not available in XML mode"
    nil
  end

  def self.sync_xml_file
    IbcosXmlSyncJob.perform_now
  end

  def self.xml_file_exists?
    File.exist?(XML_FILE_PATH)
  end

  def self.xml_file_age
    return nil unless xml_file_exists?

    Time.current - File.mtime(XML_FILE_PATH)
  end

  private

  def self.load_all_parts
    unless xml_file_exists?
      Rails.logger.warn "IBCOS XML file not found at #{XML_FILE_PATH}. Run IbcosXmlSyncJob to download."
      return []
    end

    xml_content = File.read(XML_FILE_PATH)
    doc = Nokogiri::XML(xml_content)
    
    if doc.errors.any?
      Rails.logger.error "XML parsing errors: #{doc.errors.map(&:message).join(', ')}"
    end
    
    # Parse all parts from XML (try both lowercase and uppercase)
    parts = doc.xpath('//part | //Part').map do |part|
      parse_part_node(part)
    end
    
    Rails.logger.info "Loaded #{parts.size} parts from IBCOS XML"
    parts
  rescue StandardError => e
    Rails.logger.error "Error loading IBCOS parts: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    []
  end

  def self.parse_part_node(node)
    {
      sku: node['partnumber'] || node['stockcode'],
      name: node['description'] || node['name'],
      brand: node['brand'] || node['manufacturer'],
      category: node['category'],
      retail_price: parse_decimal(node['retailprice'] || node['price']),
      cost_price: parse_decimal(node['dealernet'] || node['averageprice'] || node['cost']),
      stock: (node['freestock'] || node['stock'] || node['quantity'])&.to_i || 0
    }
  end

  def self.parse_decimal(value)
    return nil if value.blank?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end
end
