class AddSubmissionIdToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :submission_id, :bigint
    add_index :quotes, :submission_id
  end
end
