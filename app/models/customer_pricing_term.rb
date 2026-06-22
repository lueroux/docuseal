# frozen_string_literal: true

class CustomerPricingTerm < ApplicationRecord
  belongs_to :customer

  validates :discount_percentage, presence: true,
                                   numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
