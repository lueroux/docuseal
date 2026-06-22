# frozen_string_literal: true

class CreateQuoteItemOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_item_options do |t|
      t.references :quote_item, null: false, foreign_key: true
      t.references :product_option, null: true, foreign_key: true
      
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.boolean :is_selected, default: false
      t.boolean :is_included, default: false

      t.timestamps
    end
  end
end
