# frozen_string_literal: true

class AddLinkedProductToProductOptions < ActiveRecord::Migration[8.1]
  def change
    add_reference :product_options, :linked_product, references: :products, foreign_key: { to_table: :products }, index: true
  end
end
