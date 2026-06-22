# frozen_string_literal: true

class AddSkuToProductOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :product_options, :sku, :string
    add_index :product_options, :sku
  end
end
