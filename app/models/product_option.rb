# frozen_string_literal: true

class ProductOption < ApplicationRecord
  belongs_to :product
  has_many :quote_item_options, dependent: :destroy

  validates :sku, presence: true, uniqueness: { scope: :product_id }
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :option_type, presence: true, inclusion: { in: %w[addon warranty bundle] }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :required, -> { where(is_required: true) }
  scope :by_group, ->(group) { where(option_group: group) }
  scope :ordered, -> { order(:sort_order) }
end
