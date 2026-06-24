# frozen_string_literal: true

class ProductOption < ApplicationRecord
  belongs_to :product
  belongs_to :linked_product, class_name: 'Product', optional: true
  has_many :quote_item_options, dependent: :destroy

  validates :sku, presence: true, uniqueness: { scope: :product_id }
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :option_type, presence: true, inclusion: { in: %w[addon warranty bundle] }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :required, -> { where(is_required: true) }
  scope :by_group, ->(group) { where(option_group: group) }
  scope :ordered, -> { order(:sort_order) }
  scope :linked, -> { where.not(linked_product_id: nil) }

  before_validation :populate_from_linked_product, if: -> { linked_product_id.present? }

  private

  def populate_from_linked_product
    return unless linked_product
    self.sku ||= linked_product.sku
    self.name ||= linked_product.name
    self.price ||= linked_product.retail_price
    self.description ||= linked_product.short_description || linked_product.description
  end
end
