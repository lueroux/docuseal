# frozen_string_literal: true

require 'hexapdf'
require 'tempfile'
require 'open3'

class QuotePdfGenerator
  CHROMIUM_PATH = ENV.fetch('CHROMIUM_PATH', 'chromium-browser').freeze
  CHROMIUM_TIMEOUT = ENV.fetch('CHROMIUM_TIMEOUT', '30').to_i

  attr_reader :quote

  def initialize(quote)
    @quote = quote
  end

  # Generate a high-fidelity PDF from the branded HTML document using
  # Chromium headless, falling back to HexaPDF if Chromium is unavailable.
  def generate
    Rails.logger.info("QuotePdfGenerator for quote #{quote.id} (#{quote.reference_number})")

    if chromium_available?
      generate_with_chromium
    else
      Rails.logger.warn('Chromium not available — falling back to HexaPDF')
      generate_with_hexapdf
    end
  end

  private

  # ── Chromium HTML→PDF ──────────────────────────────────────────

  def generate_with_chromium
    builder = QuoteDocumentBuilder.new(quote)
    html = builder.build_html

    tmp_html = Tempfile.new(['quote', '.html'])
    tmp_pdf = Tempfile.new(['quote', '.pdf'])
    begin
      tmp_html.write(html)
      tmp_html.close

      cmd = [
        CHROMIUM_PATH,
        '--headless=new',
        '--disable-gpu',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--no-pdf-header-footer',
        '--run-all-compositor-stages-before-draw',
        '--print-to-pdf=' + tmp_pdf.path,
        'file://' + tmp_html.path
      ]

      _stdout, stderr, status = Timeout.timeout(CHROMIUM_TIMEOUT) { Open3.capture3(*cmd) }

      unless status.success?
        Rails.logger.error("Chromium PDF failed: #{stderr}")
        raise "Chromium exited with status #{status.exitstatus}"
      end

      File.read(tmp_pdf.path)
    rescue => e
      Rails.logger.error("Chromium PDF generation failed: #{e.message}")
      generate_with_hexapdf
    ensure
      tmp_html&.close
      tmp_html&.unlink
      tmp_pdf&.close
      tmp_pdf&.unlink
    end
  end

  # ── HexaPDF fallback ───────────────────────────────────────────

  def generate_with_hexapdf
    pdf = HexaPDF::Document.new
    render_main_page(pdf)
    append_attachment_pages(pdf)
    io = StringIO.new
    pdf.write(io)
    io.string
  end

  def render_main_page(pdf)
    page = pdf.pages.add
    canvas = page.canvas

    canvas.font('Helvetica', size: 24)
    canvas.text("Quote #{quote.reference_number}", at: [50, 750])
    canvas.font('Helvetica', size: 12)
    canvas.text("Date: #{quote.created_at.strftime('%d %B %Y')}", at: [50, 720])

    y_position = 680
    if quote.customer
      canvas.text("Customer: #{quote.customer.name}", at: [50, y_position])
      y_position -= 20
      canvas.text("Email: #{quote.customer.email}", at: [50, y_position])
      if quote.customer.phone.present?
        y_position -= 20
        canvas.text("Phone: #{quote.customer.phone}", at: [50, y_position])
      end
    else
      canvas.text("Customer: Not specified", at: [50, y_position])
    end

    y_position -= 40
    canvas.font('Helvetica', size: 16)
    canvas.text("Items:", at: [50, y_position])
    canvas.font('Helvetica', size: 12)
    y_position -= 30

    quote.quote_items.ordered.each do |item|
      break if y_position < 100
      canvas.text("#{item.product.name} (#{item.product.sku})", at: [50, y_position])
      canvas.text("Qty: #{item.quantity}", at: [350, y_position])
      canvas.text("£#{format('%.2f', item.line_total)}", at: [450, y_position])
      y_position -= 20
    end

    y_position -= 20
    subtotal = quote.quote_items.sum { |item| item.line_total }
    vat = subtotal * 0.20
    total = subtotal + vat

    canvas.text("Subtotal:", at: [350, y_position])
    canvas.text("£#{format('%.2f', subtotal)}", at: [450, y_position])
    y_position -= 20
    canvas.text("VAT (20%):", at: [350, y_position])
    canvas.text("£#{format('%.2f', vat)}", at: [450, y_position])
    y_position -= 20
    canvas.font('Helvetica', size: 14)
    canvas.text("Total:", at: [350, y_position])
    canvas.text("£#{format('%.2f', total)}", at: [450, y_position])
    canvas.font('Helvetica', size: 12)

    structures = quote.quote_payment_structures.order(:payment_type)
    if structures.any?
      y_position -= 40
      canvas.font('Helvetica', size: 14)
      canvas.text("Payment Options:", at: [50, y_position])
      canvas.font('Helvetica', size: 12)
      y_position -= 25

      structures.each do |ps|
        break if y_position < 60
        title = "#{ps.payment_type.titleize}#{ps.is_primary? ? ' (Primary)' : ''}"
        if ps.payment_type == 'cash'
          canvas.text("#{title}: £#{format('%.2f', ps.total_cost.to_f)}", at: [70, y_position])
          y_position -= 18
          if ps.deposit.to_f > 0
            canvas.text("  Deposit: £#{format('%.2f', ps.deposit)}", at: [70, y_position])
            y_position -= 16
          end
        else
          details = "#{title}:"
          details += " £#{format('%.2f', ps.total_cost.to_f)}" if ps.total_cost.to_f > 0
          details += " | £#{format('%.2f', ps.monthly_payment.to_f)}/mo" if ps.monthly_payment.to_f > 0
          details += " | #{ps.term_months}mo" if ps.term_months.to_i > 0
          details += " | #{ps.apr}% APR" if ps.apr.to_f > 0
          canvas.text(details, at: [70, y_position])
          y_position -= 18
          if ps.deposit.to_f > 0
            canvas.text("  Deposit: £#{format('%.2f', ps.deposit)}", at: [70, y_position])
            y_position -= 16
          end
          if ps.provider.present?
            canvas.text("  Provider: #{ps.provider}", at: [70, y_position])
            y_position -= 16
          end
        end
      end
    end

    attachments = quote.quote_attachments.ordered
    if attachments.any?
      y_position -= 30
      canvas.font('Helvetica', size: 14)
      canvas.text("Attachments:", at: [50, y_position])
      canvas.font('Helvetica', size: 12)
      y_position -= 25

      attachments.each do |att|
        break if y_position < 60
        canvas.text("#{att.name} — #{att.file.filename} (#{number_to_human_size(att.file.byte_size)})", at: [70, y_position])
        y_position -= 18
        if att.description.present?
          canvas.text("  #{att.description}", at: [70, y_position])
          y_position -= 16
        end
      end
    end
  end

  def append_attachment_pages(pdf)
    quote.quote_attachments.ordered.each do |att|
      append_attachment_page(pdf, att)
    end
  end

  def append_attachment_page(pdf, att)
    return unless att.file.attached?

    content_type = att.file.content_type.to_s.downcase

    if content_type == 'application/pdf'
      append_pdf_attachment(pdf, att)
    elsif content_type.start_with?('image/')
      append_image_attachment(pdf, att)
    else
      append_other_attachment(pdf, att)
    end
  rescue => e
    Rails.logger.error("Failed to append attachment #{att.id}: #{e.message}")
    append_fallback_page(pdf, att, e.message)
  end

  def append_pdf_attachment(pdf, att)
    tempfile = Tempfile.new(['attach', '.pdf'], binmode: true)
    begin
      att.file.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind
      other = HexaPDF::Document.open(tempfile.path)
      other.pages.each do |page|
        imported = pdf.import(page)
        canvas = imported.canvas(type: :overlay)
        canvas.font('Helvetica', size: 8)
        canvas.fill_color(128, 128, 128)
        canvas.text("#{att.name} — #{att.file.filename}", at: [20, imported.box.height - 15])
        pdf.pages << imported
      end
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  def append_image_attachment(pdf, att)
    ext = File.extname(att.file.filename.to_s)
    tempfile = Tempfile.new(['attach', ext], binmode: true)
    begin
      att.file.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind

      page = pdf.pages.add
      canvas = page.canvas
      canvas.font('Helvetica', size: 9)
      canvas.fill_color(128, 128, 128)
      canvas.text("Attachment: #{att.name} — #{att.file.filename}", at: [20, page.box.height - 20])

      image = pdf.images.add(tempfile.path)
      iw = image.info.width.to_f
      ih = image.info.height.to_f

      if iw > 0 && ih > 0
        margin = 30
        avail_w = page.box.width - (2 * margin)
        avail_h = page.box.height - 50
        scale = [avail_w / iw, avail_h / ih].min
        w = iw * scale
        h = ih * scale
        x = (page.box.width - w) / 2.0
        y = margin + (avail_h - h) / 2.0
        canvas.image(image, at: [x, y + h], width: w, height: h)
      end
    rescue => e
      Rails.logger.warn("Image embed failed for #{att.file.filename}: #{e.message}")
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  def append_other_attachment(pdf, att)
    page = pdf.pages.add
    canvas = page.canvas
    cx = page.box.width / 2

    canvas.font('Helvetica', size: 14)
    canvas.fill_color(80, 80, 80)
    canvas.text("Attached File", at: [cx - 60, page.box.height - 60])

    canvas.font('Helvetica', size: 18)
    canvas.fill_color(40, 40, 40)
    canvas.text(att.name, at: [cx - 80, page.box.height - 120])

    canvas.font('Helvetica', size: 12)
    canvas.fill_color(100, 100, 100)
    canvas.text("Filename: #{att.file.filename}", at: [cx - 100, page.box.height - 160])
    canvas.text("Type: #{att.file.content_type}", at: [cx - 100, page.box.height - 182])
    canvas.text("Size: #{number_to_human_size(att.file.byte_size)}", at: [cx - 100, page.box.height - 204])

    if att.description.present?
      canvas.text("Description: #{att.description}", at: [cx - 100, page.box.height - 232])
    end

    canvas.font('Helvetica', size: 11)
    canvas.fill_color(140, 140, 140)
    canvas.text("(This file type cannot be displayed inline in the PDF)", at: [cx - 130, page.box.height - 280])
    canvas.text("Please refer to the original file.", at: [cx - 130, page.box.height - 300])
  end

  def append_fallback_page(pdf, att, error_msg)
    page = pdf.pages.add
    canvas = page.canvas
    cx = page.box.width / 2

    canvas.font('Helvetica', size: 14)
    canvas.fill_color(180, 60, 60)
    canvas.text("Attachment Rendering Error", at: [cx - 100, page.box.height - 60])

    canvas.font('Helvetica', size: 12)
    canvas.fill_color(80, 80, 80)
    canvas.text(att.name, at: [cx - 80, page.box.height - 100])
    canvas.text("File: #{att.file.filename}", at: [cx - 100, page.box.height - 130])
    canvas.text(error_msg, at: [cx - 100, page.box.height - 160])
  end

  # ── Helpers ────────────────────────────────────────────────────

  def chromium_available?
    return @chromium_available if defined?(@chromium_available)

    _stdout, _stderr, status = Timeout.timeout(5) { Open3.capture3(CHROMIUM_PATH, '--version') }
    @chromium_available = status.success?
  rescue Errno::ENOENT, Timeout::Error
    @chromium_available = false
  end

  def number_to_human_size(bytes)
    return '0 Bytes' if bytes.nil? || bytes.zero?

    units = %w[Bytes KB MB GB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = [exp, units.length - 1].min
    format('%.1f %s', bytes.to_f / (1024 ** exp), units[exp])
  end
end
