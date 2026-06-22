# frozen_string_literal: true

class CreateQuoteItems < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_items do |t|
      t.references :quote, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      
      t.integer :quantity, null: false, default: 1
      t.decimal :cost_price, precision: 10, scale: 2
      t.decimal :retail_price, precision: 10, scale: 2
      t.decimal :quoted_price, precision: 10, scale: 2, null: false
      t.decimal :discount_percentage, precision: 5, scale: 2, default: 0.0
      
      t.text :notes
      t.integer :sort_order, default: 0

      t.timestamps
    end

    add_index :quote_items, :sort_order
  end
end
