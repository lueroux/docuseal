# frozen_string_literal: true

class ProductCompatibilityRule < ApplicationRecord
  belongs_to :product

  validates :rule_type, presence: true, inclusion: { in: %w[requires excludes suggests] }
  validates :result_action, presence: true

  scope :requires, -> { where(rule_type: 'requires') }
  scope :excludes, -> { where(rule_type: 'excludes') }
  scope :suggests, -> { where(rule_type: 'suggests') }
end
