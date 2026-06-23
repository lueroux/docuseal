# frozen_string_literal: true

class CreateQuoteAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_attachments do |t|
      t.references :quote, null: false, foreign_key: true
      t.string :name, null: false
      t.string :description
      t.integer :sort_order, default: 0, null: false

      t.timestamps
    end

    add_index :quote_attachments, %i[quote_id sort_order]
  end
end
