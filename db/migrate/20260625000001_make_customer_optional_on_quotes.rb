# frozen_string_literal: true

class MakeCustomerOptionalOnQuotes < ActiveRecord::Migration[8.1]
  def change
    change_column_null :quotes, :customer_id, true
  end
end
