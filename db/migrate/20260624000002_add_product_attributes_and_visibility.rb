# frozen_string_literal: true

class AddProductAttributesAndVisibility < ActiveRecord::Migration[8.1]
  def change
    # Add columns for storing all WooCommerce product attributes
    add_column :products, :short_description, :text
    add_column :products, :stock_status, :string
    add_column :products, :weight, :decimal, precision: 10, scale: 2
    add_column :products, :dimensions, :string
    add_column :products, :dimensions_length, :decimal, precision: 10, scale: 2
    add_column :products, :dimensions_width, :decimal, precision: 10, scale: 2
    add_column :products, :dimensions_height, :decimal, precision: 10, scale: 2
    add_column :products, :permalink, :string
    add_column :products, :date_on_sale_from, :datetime
    add_column :products, :date_on_sale_to, :datetime
    add_column :products, :sale_price, :decimal, precision: 10, scale: 2
    add_column :products, :regular_price, :decimal, precision: 10, scale: 2
    add_column :products, :manage_stock, :boolean, default: false
    add_column :products, :stock_quantity, :integer
    add_column :products, :backorders, :string
    add_column :products, :sold_individually, :boolean, default: false
    add_column :products, :virtual, :boolean, default: false
    add_column :products, :downloadable, :boolean, default: false
    add_column :products, :tax_class, :string
    add_column :products, :tax_status, :string
    add_column :products, :shipping_class, :string
    add_column :products, :external_url, :string
    add_column :products, :button_text, :string
    add_column :products, :menu_order, :integer
    add_column :products, :reviews_allowed, :boolean, default: true
    add_column :products, :average_rating, :decimal, precision: 3, scale: 2
    add_column :products, :rating_count, :integer, default: 0
    add_column :products, :total_sales, :integer, default: 0

    # Add JSONB field for storing all WooCommerce attributes as key-value pairs
    add_column :products, :woo_attributes, :jsonb, default: {}

    # Add JSONB field for attribute visibility configuration
    # Format: { "attribute_name": { "visible_on_detail_page": true/false, "label": "Display Name" } }
    add_column :products, :attribute_visibility, :jsonb, default: {}

    # Add index for JSONB queries
    add_index :products, :woo_attributes, using: :gin
    add_index :products, :attribute_visibility, using: :gin
  end
end
