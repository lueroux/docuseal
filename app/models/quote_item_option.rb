# frozen_string_literal: true

class QuoteItemOption < ApplicationRecord
  belongs_to :quote_item
  belongs_to :product_option, optional: true

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :selected, -> { where(is_selected: true) }
  scope :included, -> { where(is_included: true) }
end
