# frozen_string_literal: true

class QuoteItem < ApplicationRecord
  belongs_to :quote
  belongs_to :product
  has_many :quote_item_options, dependent: :destroy

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :quoted_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  before_validation :set_default_prices, on: :create

  scope :ordered, -> { order(:sort_order, :created_at) }

  def line_total
    quoted_price * quantity
  end

  def options_total
    quote_item_options.where(is_selected: true).sum(:price)
  end

  def total_with_options
    (quoted_price + options_total) * quantity
  end

  private

  def set_default_prices
    return unless product

    self.cost_price ||= product.cost_price
    self.retail_price ||= product.retail_price
    self.quoted_price ||= product.retail_price
  end
end
