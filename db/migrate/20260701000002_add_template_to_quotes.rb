# frozen_string_literal: true

class AddTemplateToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :template_id, :bigint
    add_foreign_key :quotes, :templates, column: :template_id
    add_index :quotes, :template_id
  end
end
