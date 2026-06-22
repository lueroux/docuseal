# frozen_string_literal: true

class CreateProductCompatibilityRules < ActiveRecord::Migration[8.1]
  def change
    create_table :product_compatibility_rules do |t|
      t.references :product, null: false, foreign_key: true, index: true
      t.string :rule_type, null: false # requires, excludes, suggests
      t.string :condition_type # sku, brand, category, option
      t.string :condition_value
      t.string :result_action # hide, disable, show_message, require
      t.string :result_value
      t.timestamps
    end

    add_index :product_compatibility_rules, [:product_id, :rule_type]
  end
end
