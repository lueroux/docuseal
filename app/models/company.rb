# frozen_string_literal: true

class Company < ApplicationRecord
  belongs_to :account
  has_many :customers, dependent: :nullify

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
