# frozen_string_literal: true

class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.jsonb :billing_address, default: {}
      t.jsonb :shipping_address, default: {}
      t.text :notes

      t.timestamps
    end

    add_index :companies, :account_id
    add_foreign_key :companies, :accounts
  end
end
