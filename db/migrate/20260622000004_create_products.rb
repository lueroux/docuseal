# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :sku, null: false
      t.string :name, null: false
      t.string :brand
      t.string :category
      t.text :description
      t.decimal :retail_price, precision: 10, scale: 2, null: false
      t.decimal :cost_price, precision: 10, scale: 2
      t.decimal :markup_percentage, precision: 5, scale: 2
      t.jsonb :spec_data, default: {}
      t.jsonb :ibcos_data, default: {}
      t.boolean :available, default: true
      t.timestamps
    end

    add_index :products, [:account_id, :sku], unique: true
    add_index :products, [:account_id, :brand]
    add_index :products, [:account_id, :category]
    add_index :products, :available
  end
end
