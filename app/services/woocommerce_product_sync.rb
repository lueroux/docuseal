# frozen_string_literal: true

class WoocommerceProductSync
  attr_reader :account, :logger

  def initialize(account)
    @account = account
    @logger = Rails.logger
  end

  # Fetch product data from WooCommerce via inkpos-api
  def fetch_by_sku(sku)
    return nil unless configured?

    # inkpos API doesn't require authentication, use a separate client without auth
    response = inkpos_client.get("/wp-json/inkpos/v1/product", params: { sku: })

    logger.info("inkpos-api fetch for SKU #{sku}: status=#{response.status}, body=#{response.body.inspect}")

    return nil unless response.success?

    parse_inkpos_response(response.body)
  rescue StandardError => e
    logger.error("WooCommerce sync error for SKU #{sku}: #{e.message}")
    nil
  end

  # Fetch variant data from WooCommerce via variants-via-api
  def fetch_variants(product_id)
    return [] unless configured?

    response = http_client.get("/wp-json/wc/v3/variants/#{product_id}")

    return [] unless response.success?

    parse_variants_response(response.body)
  rescue StandardError => e
    logger.error("WooCommerce variants sync error for product #{product_id}: #{e.message}")
    []
  end

  # Fetch WooCommerce product ID by SKU using WooCommerce REST API
  def fetch_product_id_by_sku(sku)
    return nil unless configured?

    response = http_client.get("/wp-json/wc/v3/products", params: { sku: })

    logger.info("WooCommerce product ID lookup for SKU #{sku}: status=#{response.status}, body=#{response.body.inspect}")

    return nil unless response.success?

    products = response.body
    return nil unless products.is_a?(Array) && products.any?

    # Validate that the returned product's SKU matches what we searched for
    returned_product = products.first
    returned_sku = returned_product['sku']
    
    if returned_sku != sku
      logger.warn("WooCommerce SKU mismatch: searched for '#{sku}' but got product with SKU '#{returned_sku}' (ID: #{returned_product['id']})")
      return nil
    end

    logger.info("WooCommerce product ID found for SKU #{sku}: #{returned_product['id']}")
    returned_product['id']
  rescue StandardError => e
    logger.error("WooCommerce product ID fetch error for SKU #{sku}: #{e.message}")
    nil
  end

  # Fetch product details from standard WooCommerce REST API by ID or SKU
  def fetch_from_standard_wc(sku_or_id)
    return nil unless configured?

    response = if sku_or_id.to_s.match?(/\A\d+\z/)
                 http_client.get("/wp-json/wc/v3/products/#{sku_or_id}")
               else
                 http_client.get("/wp-json/wc/v3/products", params: { sku: sku_or_id })
               end

    logger.info("Standard WC API fetch for #{sku_or_id}: status=#{response.status}, body=#{response.body.inspect}")

    return nil unless response.success?

    data = response.body
    product_data = data.is_a?(Array) ? data.first : data
    return nil unless product_data

    # If we searched by SKU, validate the returned product's SKU matches
    if !sku_or_id.to_s.match?(/\A\d+\z/) && product_data['sku'] != sku_or_id
      logger.warn("WooCommerce SKU mismatch in standard API: searched for '#{sku_or_id}' but got product with SKU '#{product_data['sku']}'")
      return nil
    end

    parse_standard_wc_response(product_data)
  rescue StandardError => e
    logger.error("WooCommerce standard API fetch error for #{sku_or_id}: #{e.message}")
    nil
  end

  def parse_standard_wc_response(data)
    {
      sku: data['sku'],
      name: data['name'] || data['sku'],
      brand: nil,
      category: data['categories']&.first&.[]('name'),
      description: data['description'],
      retail_price: parse_price(data['regular_price'] || data['price']),
      cost_price: nil,
      image_url: data['images']&.first&.[]('src'),
      woocommerce_product_id: data['id'],
      spec_data: {}
    }
  end

  # Sync a single product from WooCommerce data
  def sync_product!(sku)
    logger.info("Starting sync for SKU: #{sku}")
    product = Product.find_or_initialize_by(account:, sku:)
    was_new_record = product.new_record?

    logger.info("Product record: woocommerce_product_id=#{product.woocommerce_product_id.inspect}, was_new_record=#{was_new_record}")

    # Always fetch the product ID by SKU to ensure correctness, even if already stored
    woo_product_id = fetch_product_id_by_sku(sku)
    logger.info("Fetched product ID by SKU: #{woo_product_id.inspect}")
    if woo_product_id
      product.woocommerce_product_id = woo_product_id
    end

    # Fetch product data from WooCommerce (prefer custom inkpos-api first for battery specs)
    woo_data = fetch_by_sku(sku)
    logger.info("inkpos-api result: #{woo_data.inspect}")

    # Fallback to standard WooCommerce REST API if inkpos-api does not return the product
    if woo_data.nil?
      # Always search by SKU to ensure we get the correct product
      logger.info("Falling back to standard WC API with SKU: #{sku.inspect}")
      woo_data = fetch_from_standard_wc(sku)
      logger.info("Standard WC API result: #{woo_data.inspect}")
    end

    return { success: false, error: 'Product not found in WooCommerce' } unless woo_data

    # Update fields that aren't manually edited
    update_product_from_woo_data(product, woo_data)

    # Make sure we store the product ID if we got it from the synced data
    if product.woocommerce_product_id.blank? && woo_data[:woocommerce_product_id].present?
      product.woocommerce_product_id = woo_data[:woocommerce_product_id]
    end

    product.synced_at = Time.current

    if product.save
      logger.info("Product sync successful for SKU #{sku}")
      { success: true, product:, was_new_record: }
    else
      logger.error("Product sync failed for SKU #{sku}: #{product.errors.full_messages.to_sentence}")
      { success: false, error: product.errors.full_messages.to_sentence }
    end
  end

  # Sync all products for an account
  def sync_all!
    return { success: false, error: 'WooCommerce not configured' } unless configured?

    # Fetch all products from WooCommerce (would need a bulk endpoint)
    # For now, sync by iterating existing products
    results = { synced: 0, failed: 0, errors: [] }

    account.products.find_each do |product|
      result = sync_product!(product.sku)
      if result[:success]
        results[:synced] += 1
      else
        results[:failed] += 1
        results[:errors] << { sku: product.sku, error: result[:error] }
      end
    end

    results
  end

  def configured?
    woo_url.present? && woo_consumer_key.present? && woo_consumer_secret.present?
  end

  private

  def woo_url
    @woo_url ||= EncryptedConfig.find_by(account:, key: 'woocommerce_url')&.value
  end

  def woo_consumer_key
    @woo_consumer_key ||= EncryptedConfig.find_by(account:, key: 'woocommerce_consumer_key')&.value
  end

  def woo_consumer_secret
    @woo_consumer_secret ||= EncryptedConfig.find_by(account:, key: 'woocommerce_consumer_secret')&.value
  end

  def http_client
    @http_client ||= Faraday.new(url: woo_url) do |faraday|
      faraday.request :authorization, :basic, woo_consumer_key, woo_consumer_secret
      faraday.request :url_encoded
      faraday.response :json
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = 30
    end
  end

  def inkpos_client
    @inkpos_client ||= Faraday.new(url: woo_url) do |faraday|
      faraday.request :url_encoded
      faraday.response :json
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = 30
      faraday.headers['X-API-Key'] = 'inkpos_ae6ecab0aba2f2009c0ac66aa1204ed699dc2235'
    end
  end

  def parse_inkpos_response(response_body)
    # inkpos API wraps product data in a 'data' key
    data = response_body.is_a?(Hash) ? (response_body['data'] || response_body) : response_body

    {
      sku: data['sku'],
      name: data['model'] || data['sku'],
      brand: data['brand'] || extract_brand(data),
      category: data['categories'] || data['machine_type'],
      description: data['longer_description'] || data['long_desc'] || data['short_desc'],
      retail_price: parse_price(data['pa_rrp'] || data['price'] || data['recommended_bundle_price'] || data['recommended_battery_price']),
      cost_price: parse_price(data['price_ex_tax']),
      image_url: nil,
      woocommerce_product_id: nil,
      spec_data: {
        battery_system: data['battery_sys'],
        recommended_battery: data['recommended_battery'],
        recommended_battery_rrp: data['recommended_battery_rrp'],
        recommended_battery_price: data['recommended_battery_price'],
        recommended_charger: data['recommended_charger'],
        recommended_charger_rrp: data['recommended_charger_rrp'],
        recommended_charger_price: data['recommended_charger_price'],
        recommended_bundle_rrp: data['recommended_bundle_rrp'],
        recommended_bundle_price: data['recommended_bundle_price'],
        power_source: data['power_source'],
        user_type: data['user_type'],
        key_specs: data['key_specs']
      }.compact
    }
  end

  def parse_variants_response(data)
    return [] unless data['variants'].is_a?(Array)

    data['variants'].map do |variant|
      {
        sku: variant['variation_sku'],
        name: variant['variation_name'],
        price: parse_price(variant['price']),
        rrp: parse_price(variant['pa_rrp']),
        attributes: variant['attributes']
      }
    end
  end

  def extract_brand(data)
    # inkpos-api strips brand from model name
    # We could infer from taxonomy or store in a separate field
    nil
  end

  def parse_price(value)
    return nil if value.nil? || value.to_s.strip.empty?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end

  def update_product_from_woo_data(product, woo_data)
    # Name - only update if not manually edited
    product.name = woo_data[:name] unless product.manually_edited?('name')

    # Brand - only update if not manually edited
    product.brand = woo_data[:brand] unless product.manually_edited?('brand')

    # Category - only update if not manually edited
    product.category = woo_data[:category] unless product.manually_edited?('category')

    # Description - only update if not manually edited
    product.description = woo_data[:description] unless product.manually_edited?('description')

    # Retail price - only update if not manually edited
    product.retail_price = woo_data[:retail_price] unless product.manually_edited?('retail_price')

    # Image URL - only update if not manually edited
    product.image_url = woo_data[:image_url] unless product.manually_edited?('image_url')

    # Merge spec_data (additive, don't remove existing keys)
    if woo_data[:spec_data].present?
      product.spec_data ||= {}
      product.spec_data = product.spec_data.merge(woo_data[:spec_data])
    end
  end
end
