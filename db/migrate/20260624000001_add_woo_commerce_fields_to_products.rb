# frozen_string_literal: true

class AddWooCommerceFieldsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :woocommerce_product_id, :integer
    add_column :products, :image_url, :string
    add_column :products, :synced_at, :datetime
    add_column :products, :manual_edit_flags, :jsonb, default: {}

    add_index :products, :woocommerce_product_id
  end
end
