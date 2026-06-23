# frozen_string_literal: true

class QuotePaymentStructure < ApplicationRecord
  belongs_to :quote

  validates :payment_type, presence: true, 
            inclusion: { in: %w[cash finance lease] }
  validates :total_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :primary, -> { where(is_primary: true) }
  scope :by_type, ->(type) { where(payment_type: type) }

  before_save :enforce_single_primary

  private

  def enforce_single_primary
    return unless is_primary?

    quote.quote_payment_structures.where.not(id: id).update_all(is_primary: false)
  end
end
