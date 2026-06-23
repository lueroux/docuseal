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
      parts = load_all_parts
      
      # Find exact match by SKU
      parts.find { |part| part[:sku]&.downcase == part_no.downcase }
    end
  rescue StandardError => e
    Rails.logger.error "IBCOS quick search error: #{e.message}"
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
    
    # Parse all parts from XML
    doc.xpath('//Part').map do |part|
      parse_part_node(part)
    end
  end

  def self.parse_part_node(node)
    {
      sku: node.at_xpath('PartNo')&.text || node.at_xpath('StockCode')&.text,
      name: node.at_xpath('Description')&.text || node.at_xpath('Name')&.text,
      brand: node.at_xpath('Brand')&.text || node.at_xpath('Manufacturer')&.text,
      category: node.at_xpath('Category')&.text || node.at_xpath('Group')&.text,
      retail_price: parse_decimal(node.at_xpath('Price')&.text || node.at_xpath('RetailPrice')&.text),
      cost_price: parse_decimal(node.at_xpath('Cost')&.text || node.at_xpath('CostPrice')&.text),
      stock: (node.at_xpath('Stock')&.text || node.at_xpath('Quantity')&.text)&.to_i || 0
    }
  end

  def self.parse_decimal(value)
    return nil if value.blank?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end
end
