# frozen_string_literal: true

class QuoteSigningService
  attr_reader :quote, :user

  def initialize(quote, user)
    @quote = quote
    @user = user
    @account = quote.account
  end

  # Creates a Docuseal template from the quote PDF, creates a submission
  # for the customer, sends the signing email, and links everything.
  def send_for_signing!
    raise ArgumentError, 'Quote has no customer' unless quote.customer&.email.present?
    raise ArgumentError, 'Quote has no items' unless quote.quote_items.any?

    pdf_data = QuotePdfGenerator.new(quote).generate
    template = create_template!(pdf_data)
    submission = create_submission!(template)
    link_and_send!(submission)
    submission
  end

  private

  def create_template!(pdf_data)
    uuid = SecureRandom.uuid

    template = account.templates.new(
      author: user,
      folder: TemplateFolders.find_or_create_by_name(user, 'Quotes'),
      name: "Quote #{quote.reference_number}",
      source: 'native',
      fields: [
        build_signature_field(uuid),
        build_date_field(uuid)
      ],
      schema: [],
      submitters: [
        { 'name' => 'Customer', 'uuid' => uuid }
      ]
    )

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(pdf_data),
      filename: "quote-#{quote.reference_number}.pdf",
      content_type: 'application/pdf'
    )

    template.documents.attach(blob)
    template.schema = [
      { 'attachment_uuid' => blob.uuid, 'name' => "quote-#{quote.reference_number}.pdf" }
    ]
    template.save!

    template
  end

  def create_submission!(template)
    submission = template.submissions.new(
      created_by_user: user,
      account_id: account.id,
      source: :invite,
      template_submitters: template.submitters.as_json,
      submitters_order: :preserved,
      expire_at: quote.valid_until.presence || 30.days.from_now
    )

    submission.submitters.new(
      email: quote.customer.email,
      name: quote.customer.name,
      uuid: template.submitters.first['uuid'],
      account_id: account.id,
      sent_at: Time.current
    )

    submission.save!
    submission
  end

  def link_and_send!(submission)
    quote.update!(
      submission_id: submission.id,
      status: :sent,
      sent_at: Time.current
    )

    Submissions.send_signature_requests([submission])
  end

  def build_signature_field(submitter_uuid)
    {
      'uuid' => SecureRandom.uuid,
      'submitter_uuid' => submitter_uuid,
      'name' => 'signature',
      'type' => 'signature',
      'required' => true,
      'readonly' => false,
      'title' => 'Signature',
      'preferences' => {},
      'areas' => [
        { 'x' => 20, 'y' => 20, 'w' => 200, 'h' => 60, 'page' => 0 }
      ]
    }
  end

  def build_date_field(submitter_uuid)
    {
      'uuid' => SecureRandom.uuid,
      'submitter_uuid' => submitter_uuid,
      'name' => 'date',
      'type' => 'date',
      'required' => true,
      'readonly' => true,
      'title' => 'Date',
      'preferences' => { 'format' => 'dd/MM/yyyy' },
      'areas' => [
        { 'x' => 20, 'y' => 90, 'w' => 120, 'h' => 30, 'page' => 0 }
      ]
    }
  end

  private

  attr_reader :account
end
