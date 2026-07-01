# frozen_string_literal: true

class ProductDocument < ApplicationRecord
  belongs_to :product

  has_one_attached :file

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    image/png image/jpeg image/jpg image/gif image/webp
  ].freeze

  validates :name, presence: true
  validate :file_attached
  validate :file_content_type

  scope :ordered, -> { order(:sort_order, :created_at) }

  def pdf?
    file.attached? && file.content_type == 'application/pdf'
  end

  def image?
    file.attached? && file.content_type.start_with?('image/')
  end

  private

  def file_attached
    errors.add(:file, 'must be attached') unless file.attached?
  end

  def file_content_type
    return unless file.attached?
    return if ALLOWED_CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, "type #{file.content_type} is not permitted")
  end
end
