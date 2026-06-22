# frozen_string_literal: true

class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.bigint :account_id, null: false
      t.bigint :company_id
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.jsonb :billing_address, default: {}
      t.jsonb :shipping_address, default: {}
      t.string :portal_token
      t.datetime :portal_token_expires_at
      t.text :notes

      t.timestamps
    end

    add_index :customers, :account_id
    add_index :customers, :company_id
    add_index :customers, :email
    add_index :customers, :portal_token, unique: true
    add_foreign_key :customers, :accounts
    add_foreign_key :customers, :companies
  end
end
