# frozen_string_literal: true

class QuoteAttachment < ApplicationRecord
  belongs_to :quote

  has_one_attached :file

  validates :name, presence: true
  validates :file, attached: true, content_type: %w[
    application/pdf
    image/png image/jpeg image/jpg image/gif image/webp
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
  ]

  scope :ordered, -> { order(:sort_order, :created_at) }

  def image?
    file.attached? && file.content_type.start_with?('image/')
  end

  def pdf?
    file.attached? && file.content_type == 'application/pdf'
  end
end
