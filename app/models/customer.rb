# frozen_string_literal: true

class Customer < ApplicationRecord
  belongs_to :account
  belongs_to :company, optional: true
  has_many :customer_pricing_terms, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true,
                    format: { with: /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\z/ }
  validates :email, uniqueness: { scope: :account_id }

  scope :ordered, -> { order(:name) }

  def generate_portal_token!
    update!(
      portal_token: SecureRandom.urlsafe_base64(32),
      portal_token_expires_at: 1.hour.from_now
    )
  end

  def portal_token_valid?
    portal_token.present? && portal_token_expires_at&.future?
  end

  def invalidate_portal_token!
    update!(portal_token: nil, portal_token_expires_at: nil)
  end
end
