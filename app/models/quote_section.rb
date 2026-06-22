# frozen_string_literal: true

class QuoteSection < ApplicationRecord
  belongs_to :quote

  validates :section_type, presence: true, 
            inclusion: { in: %w[cover spec_sheet pricing terms attachment] }

  scope :ordered, -> { order(:sort_order) }
  scope :visible, -> { where(is_visible: true) }
  scope :by_type, ->(type) { where(section_type: type) }
end
