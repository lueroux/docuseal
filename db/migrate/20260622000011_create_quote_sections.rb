# frozen_string_literal: true

class CreateQuoteSections < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_sections do |t|
      t.references :quote, null: false, foreign_key: true
      
      t.string :section_type, null: false
      t.string :title
      t.jsonb :content, default: {}
      t.integer :sort_order, default: 0
      t.boolean :is_visible, default: true

      t.timestamps
    end

    add_index :quote_sections, :section_type
    add_index :quote_sections, :sort_order
  end
end
