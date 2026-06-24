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

  before_update :mark_changed_fields_as_manually_edited

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

  def attribute_visible?(key)
    visibility = attribute_visibility&.dig(key)
    visibility.nil? || visibility['visible_on_detail_page'] != false
  end

  def attribute_label(key)
    attribute_visibility&.dig(key, 'label') || key.humanize
  end

  def calculate_retail_price
    return retail_price if cost_price.blank? || markup_percentage.blank?

    (cost_price * (1 + markup_percentage / 100.0)).round(2)
  end

  private

  def mark_changed_fields_as_manually_edited
    # Auto-mark non-price fields as manually edited when they change in the admin
    # Price is intentionally excluded so website data can keep quotes current
    protected_fields = %w[name brand category description image_url woocommerce_product_id]

    protected_fields.each do |field|
      mark_manually_edited(field) if saved_change_to_attribute?(field)
    end
  end
end
