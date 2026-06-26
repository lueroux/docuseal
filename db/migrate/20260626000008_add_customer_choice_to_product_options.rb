class AddCustomerChoiceToProductOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :product_options, :customer_choice, :boolean, default: false, null: false
    add_index :product_options, :customer_choice
  end
end
