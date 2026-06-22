# frozen_string_literal: true

class IbcosGoldService
  CACHE_TTL = 15.minutes

  def self.search_parts(expression:, max_results: 25)
    Rails.cache.fetch("ibcos:search:#{expression}:#{max_results}", expires_in: CACHE_TTL) do
      execute_request('PartEnquiry', expression:, max_results:)
    end
  rescue StandardError => e
    Rails.logger.error "IBCOS search error: #{e.message}"
    []
  end

  def self.quick_part_search(part_no:)
    Rails.cache.fetch("ibcos:quick:#{part_no}", expires_in: CACHE_TTL) do
      execute_request('QuickPartEnquiry', part_no:)
    end
  rescue StandardError => e
    Rails.logger.error "IBCOS quick search error: #{e.message}"
    nil
  end

  def self.part_price(part_no:, customer_account:)
    Rails.cache.fetch("ibcos:price:#{part_no}:#{customer_account}", expires_in: CACHE_TTL) do
      execute_request('PartPrice', part_no:, customer_account:)
    end
  rescue StandardError => e
    Rails.logger.error "IBCOS price error: #{e.message}"
    nil
  end

  def self.customer_info(customer_account:)
    Rails.cache.fetch("ibcos:customer:#{customer_account}", expires_in: CACHE_TTL) do
      execute_request('CustomerInfo', customer_account:)
    end
  rescue StandardError => e
    Rails.logger.error "IBCOS customer info error: #{e.message}"
    nil
  end

  private

  def self.execute_request(action, **params)
    credentials = fetch_credentials
    return nil unless credentials

    connection = Faraday.new(url: credentials[:url]) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    xml_request = build_xml_request(action, credentials, params)

    response = connection.post do |req|
      req.headers['Content-Type'] = 'application/xml'
      req.body = xml_request
    end

    parse_xml_response(response.body, action)
  end

  def self.fetch_credentials
    config = EncryptedConfig.find_by(key: EncryptedConfig::IBCOS_GOLD_KEY)
    return nil unless config

    data = config.data
    {
      url: data['url'],
      username: data['username'],
      password: data['password'],
      company: data['company'],
      depot: data['depot']
    }
  rescue StandardError => e
    Rails.logger.error "IBCOS credentials error: #{e.message}"
    nil
  end

  def self.build_xml_request(action, credentials, params)
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.send('Envelope', 'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/') do
        xml.send('Body') do
          xml.send(action, 'xmlns' => 'http://tempuri.org/') do
            xml.send('Credentials') do
              xml.send('Username', credentials[:username])
              xml.send('Password', credentials[:password])
              xml.send('Company', credentials[:company])
              xml.send('Depot', credentials[:depot])
            end

            case action
            when 'PartEnquiry'
              xml.send('Expression', params[:expression])
              xml.send('MaxResults', params[:max_results])
            when 'QuickPartEnquiry'
              xml.send('PartNo', params[:part_no])
            when 'PartPrice'
              xml.send('PartNo', params[:part_no])
              xml.send('CustomerAccount', params[:customer_account])
            when 'CustomerInfo'
              xml.send('CustomerAccount', params[:customer_account])
            end
          end
        end
      end
    end

    builder.to_xml
  end

  def self.parse_xml_response(xml_body, action)
    doc = Nokogiri::XML(xml_body)
    result_node = doc.at_xpath("//#{action}Result")

    return nil unless result_node

    case action
    when 'PartEnquiry'
      parse_parts(result_node)
    when 'QuickPartEnquiry'
      parse_part(result_node)
    when 'PartPrice'
      parse_price(result_node)
    when 'CustomerInfo'
      parse_customer(result_node)
    end
  end

  def self.parse_parts(node)
    node.xpath('//Part').map do |part|
      {
        sku: part.at_xpath('PartNo')&.text,
        name: part.at_xpath('Description')&.text,
        brand: part.at_xpath('Brand')&.text,
        category: part.at_xpath('Category')&.text,
        retail_price: parse_decimal(part.at_xpath('Price')&.text),
        cost_price: parse_decimal(part.at_xpath('Cost')&.text),
        stock: part.at_xpath('Stock')&.text&.to_i
      }
    end
  end

  def self.parse_part(node)
    {
      sku: node.at_xpath('PartNo')&.text,
      name: node.at_xpath('Description')&.text,
      brand: node.at_xpath('Brand')&.text,
      retail_price: parse_decimal(node.at_xpath('Price')&.text),
      cost_price: parse_decimal(node.at_xpath('Cost')&.text),
      stock: node.at_xpath('Stock')&.text&.to_i
    }
  end

  def self.parse_price(node)
    {
      retail_price: parse_decimal(node.at_xpath('Price')&.text),
      cost_price: parse_decimal(node.at_xpath('Cost')&.text),
      discount_percentage: parse_decimal(node.at_xpath('Discount')&.text)
    }
  end

  def self.parse_customer(node)
    {
      account: node.at_xpath('Account')&.text,
      name: node.at_xpath('Name')&.text,
      discount_percentage: parse_decimal(node.at_xpath('Discount')&.text)
    }
  end

  def self.parse_decimal(value)
    return nil if value.blank?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end
end
