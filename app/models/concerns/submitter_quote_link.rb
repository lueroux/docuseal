# frozen_string_literal: true

module SubmitterQuoteLink
  extend ActiveSupport::Concern

  included do
    after_commit :update_linked_quote_status, on: :update, if: :saved_change_to_completed_at?
  end

  private

  def update_linked_quote_status
    return unless completed_at?

    quote = Quote.find_by(submission_id: submission_id)
    return unless quote

    quote.update!(
      status: :accepted,
      signed_at: completed_at
    )
  end
end
