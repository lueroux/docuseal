# frozen_string_literal: true

class Quote < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :customer
  has_many :quote_items, dependent: :destroy
  has_many :quote_sections, dependent: :destroy
  has_many :quote_payment_structures, dependent: :destroy
  has_many :products, through: :quote_items

  validates :reference_number, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[draft sent viewed accepted declined expired] }
  validates :total_price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :generate_reference_number, on: :create

  scope :drafts, -> { where(status: 'draft') }
  scope :sent, -> { where(status: 'sent') }
  scope :active, -> { where(status: %w[draft sent viewed]) }
  scope :expired, -> { where('valid_until < ?', Date.today) }
  scope :by_customer, ->(customer_id) { where(customer_id:) }
  scope :recent, -> { order(created_at: :desc) }

  def draft?
    status == 'draft'
  end

  def sent?
    status == 'sent'
  end

  def accepted?
    status == 'accepted'
  end

  def expired?
    valid_until.present? && valid_until < Date.today
  end

  def calculate_total
    quote_items.sum { |item| item.quoted_price * item.quantity }
  end

  def mark_as_sent!
    update!(status: 'sent', sent_at: Time.current)
  end

  def mark_as_viewed!
    update!(status: 'viewed', viewed_at: Time.current) if sent?
  end

  def mark_as_accepted!
    update!(status: 'accepted', signed_at: Time.current)
  end

  def mark_as_declined!
    update!(status: 'declined')
  end

  private

  def generate_reference_number
    return if reference_number.present?

    prefix = "Q#{Date.today.strftime('%Y%m')}"
    last_quote = Quote.where('reference_number LIKE ?', "#{prefix}%").order(:reference_number).last
    
    if last_quote
      last_number = last_quote.reference_number.split('-').last.to_i
      self.reference_number = "#{prefix}-#{(last_number + 1).to_s.rjust(4, '0')}"
    else
      self.reference_number = "#{prefix}-0001"
    end
  end
end
