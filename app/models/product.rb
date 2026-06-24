# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :account
  has_many :product_options, dependent: :destroy
  has_many :product_compatibility_rules, dependent: :destroy
  has_many :quote_items, dependent: :nullify

  validates :sku, presence: true, uniqueness: { scope: :account_id }
  validates :name, presence: true
  validates :retail_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :markup_percentage, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :available, -> { where(available: true) }
  scope :by_brand, ->(brand) { where(brand:) }
  scope :by_category, ->(category) { where(category:) }

  # Manual edit flags - keys that have been manually edited and shouldn't be overwritten by sync
  def manually_edited?(field)
    manual_edit_flags&.dig(field) == true
  end

  def mark_manually_edited(field)
    self.manual_edit_flags ||= {}
    self.manual_edit_flags[field] = true
  end

  def clear_manual_edit_flag(field)
    manual_edit_flags&.delete(field)
  end

  def synced?
    synced_at.present?
  end

  def display_name
    "#{brand} #{name} (#{sku})".strip
  end

  def calculate_retail_price
    return retail_price if cost_price.blank? || markup_percentage.blank?

    (cost_price * (1 + markup_percentage / 100.0)).round(2)
  end
end
