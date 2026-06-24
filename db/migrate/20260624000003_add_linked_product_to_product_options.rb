# frozen_string_literal: true

class AddLinkedProductToProductOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :product_options, :linked_product_id, :integer
    add_foreign_key :product_options, :products, column: :linked_product_id
    add_index :product_options, :linked_product_id
  end
end
