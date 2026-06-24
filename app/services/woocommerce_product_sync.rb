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

    response = http_client.get("/wp-json/inkpos/v1/product", params: { sku: })

    return nil unless response.success?

    parse_inkpos_response(response.parsed_response)
  rescue StandardError => e
    logger.error("WooCommerce sync error for SKU #{sku}: #{e.message}")
    nil
  end

  # Fetch variant data from WooCommerce via variants-via-api
  def fetch_variants(product_id)
    return [] unless configured?

    response = http_client.get("/wp-json/wc/v3/variants/#{product_id}")

    return [] unless response.success?

    parse_variants_response(response.parsed_response)
  rescue StandardError => e
    logger.error("WooCommerce variants sync error for product #{product_id}: #{e.message}")
    []
  end

  # Fetch WooCommerce product ID by SKU using WooCommerce REST API
  def fetch_product_id_by_sku(sku)
    return nil unless configured?

    response = http_client.get("/wp-json/wc/v3/products", params: { sku: })

    return nil unless response.success?

    products = response.parsed_response
    return nil unless products.is_a?(Array) && products.any?

    products.first['id']
  rescue StandardError => e
    logger.error("WooCommerce product ID fetch error for SKU #{sku}: #{e.message}")
    nil
  end

  # Sync a single product from WooCommerce data
  def sync_product!(sku)
    woo_data = fetch_by_sku(sku)
    return { success: false, error: 'Product not found in WooCommerce' } unless woo_data

    product = Product.find_or_initialize_by(account:, sku:)
    was_new_record = product.new_record?

    # Update fields that aren't manually edited
    update_product_from_woo_data(product, woo_data)

    # Automatically fetch WooCommerce product ID by SKU
    woo_product_id = fetch_product_id_by_sku(sku)
    product.woocommerce_product_id = woo_product_id if woo_product_id

    product.synced_at = Time.current

    if product.save
      { success: true, product:, was_new_record: }
    else
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

  private

  def configured?
    woo_url.present? && woo_consumer_key.present? && woo_consumer_secret.present?
  end

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
      faraday.request :basic_auth, woo_consumer_key, woo_consumer_secret
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = 30
    end
  end

  def parse_inkpos_response(data)
    {
      sku: data['sku'],
      name: data['model'] || data['sku'],
      brand: extract_brand(data),
      category: data['machine_type'],
      description: nil, # inkpos-api doesn't return description
      retail_price: parse_price(data['recommended_bundle_price'] || data['recommended_battery_price']),
      cost_price: nil, # Not provided by inkpos-api
      image_url: nil, # Would need separate endpoint for images
      woocommerce_product_id: nil, # inkpos-api doesn't return product ID
      spec_data: {
        battery_system: data['battery_sys'],
        recommended_battery: data['recommended_battery'],
        recommended_battery_rrp: data['recommended_battery_rrp'],
        recommended_battery_price: data['recommended_battery_price'],
        recommended_charger: data['recommended_charger'],
        recommended_charger_rrp: data['recommended_charger_rrp'],
        recommended_charger_price: data['recommended_charger_price'],
        recommended_bundle_rrp: data['recommended_bundle_rrp'],
        recommended_bundle_price: data['recommended_bundle_price']
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
