# frozen_string_literal: true

class CreateCustomerPricingTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_pricing_terms do |t|
      t.bigint :customer_id, null: false
      t.string :brand
      t.string :category
      t.decimal :discount_percentage, precision: 5, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_index :customer_pricing_terms, :customer_id
    add_foreign_key :customer_pricing_terms, :customers
  end
end
