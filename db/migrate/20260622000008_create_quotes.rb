# frozen_string_literal: true

class CreateQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :quotes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      
      t.string :reference_number, null: false
      t.string :status, null: false, default: 'draft'
      t.string :title
      t.text :notes
      t.text :internal_notes
      
      t.date :valid_until
      t.datetime :sent_at
      t.datetime :viewed_at
      t.datetime :signed_at
      
      t.decimal :total_price, precision: 10, scale: 2, default: 0.0
      t.integer :version_number, default: 1

      t.timestamps
    end

    add_index :quotes, :reference_number, unique: true
    add_index :quotes, :status
    add_index :quotes, :valid_until
  end
end
