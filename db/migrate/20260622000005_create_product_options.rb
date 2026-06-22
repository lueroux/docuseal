# frozen_string_literal: true

class CreateProductOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :product_options do |t|
      t.references :product, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.boolean :is_required, default: false
      t.string :option_group
      t.string :option_type, null: false # addon, warranty, bundle
      t.integer :sort_order, default: 0
      t.timestamps
    end

    add_index :product_options, [:product_id, :option_group]
    add_index :product_options, [:product_id, :sort_order]
  end
end
