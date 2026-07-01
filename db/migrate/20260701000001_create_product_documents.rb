# frozen_string_literal: true

class CreateProductDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :product_documents do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name
      t.integer :sort_order, default: 0

      t.timestamps
    end

    add_index :product_documents, [:product_id, :sort_order]
  end
end
