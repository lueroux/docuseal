# frozen_string_literal: true

class CreateQuotePaymentStructures < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_payment_structures do |t|
      t.references :quote, null: false, foreign_key: true
      
      t.string :payment_type, null: false
      t.integer :term_months
      t.decimal :deposit, precision: 10, scale: 2
      t.decimal :monthly_payment, precision: 10, scale: 2
      t.decimal :total_cost, precision: 10, scale: 2
      t.decimal :apr, precision: 5, scale: 2
      t.string :provider
      t.boolean :is_primary, default: false

      t.timestamps
    end

    add_index :quote_payment_structures, :payment_type
    add_index :quote_payment_structures, :is_primary
  end
end
