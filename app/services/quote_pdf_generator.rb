# frozen_string_literal: true

require 'hexapdf'
require 'tempfile'

class QuotePdfGenerator
  attr_reader :quote

  def initialize(quote)
    @quote = quote
  end

  def generate
    Rails.logger.info("QuotePdfGenerator#generate called for quote #{quote.id}")
    Rails.logger.info("Quote reference: #{quote.reference_number}")
    Rails.logger.info("Quote customer: #{quote.customer&.name}")
    
    # Create PDF using HexaPDF
    pdf = HexaPDF::Document.new
    
    # Add a page
    page = pdf.pages.add
    canvas = page.canvas
    
    # Set up fonts
    canvas.font('Helvetica', size: 12)
    
    # Add title
    canvas.text("Quote #{quote.reference_number}", at: [50, 750], font_size: 24)
    canvas.text("Date: #{quote.created_at.strftime('%d %B %Y')}", at: [50, 720])
    
    # Add customer details
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
    
    # Add quote items
    y_position -= 40
    canvas.text("Items:", at: [50, y_position], font_size: 16)
    y_position -= 30
    
    quote.quote_items.ordered.each do |item|
      break if y_position < 100
      
      canvas.text("#{item.product.name} (#{item.product.sku})", at: [50, y_position])
      canvas.text("Qty: #{item.quantity}", at: [350, y_position])
      canvas.text("£#{format('%.2f', item.total_with_options)}", at: [450, y_position])
      y_position -= 20
    end
    
    # Add total
    y_position -= 20
    subtotal = quote.quote_items.sum { |item| item.total_with_options }
    vat = subtotal * 0.20
    total = subtotal + vat
    
    canvas.text("Subtotal:", at: [350, y_position])
    canvas.text("£#{format('%.2f', subtotal)}", at: [450, y_position])
    y_position -= 20
    
    canvas.text("VAT (20%):", at: [350, y_position])
    canvas.text("£#{format('%.2f', vat)}", at: [450, y_position])
    y_position -= 20
    
    canvas.text("Total:", at: [350, y_position], font_size: 14)
    canvas.text("£#{format('%.2f', total)}", at: [450, y_position], font_size: 14)

    # Add payment structures
    structures = quote.quote_payment_structures.order(:payment_type)
    if structures.any?
      y_position -= 40
      canvas.text("Payment Options:", at: [50, y_position], font_size: 14)
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

    # Add attachments — list them in the body
    attachments = quote.quote_attachments.ordered
    if attachments.any?
      y_position -= 30
      canvas.text("Attachments:", at: [50, y_position], font_size: 14)
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

    # Append each attachment as its own page(s)
    attachments.each do |att|
      append_attachment_page(pdf, att)
    end
    
    # Output PDF
    io = StringIO.new
    pdf.write(io)
    io.string
  end

  private

  def append_attachment_page(pdf, att)
    return unless att.file.attached?

    content_type = att.file.content_type.to_s.downcase
    filename = att.file.filename.to_s

    if content_type == 'application/pdf'
      append_pdf_attachment(pdf, att)
    elsif content_type.start_with?('image/')
      append_image_attachment(pdf, att)
    else
      append_other_attachment(pdf, att)
    end
  rescue => e
    Rails.logger.error("Failed to append attachment #{att.id} (#{att.file.filename}): #{e.message}")
    append_fallback_page(pdf, att, e.message)
  end

  def append_pdf_attachment(pdf, att)
    tempfile = nil
    begin
      tempfile = Tempfile.new(['attach', '.pdf'], binmode: true)
      att.file.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind

      other = HexaPDF::Document.open(tempfile.path)
      other.pages.each do |page|
        imported = pdf.import(page)
        # Add a small label at the top
        canvas = imported.canvas(type: :overlay)
        canvas.font('Helvetica', size: 8)
        canvas.fill_color(128, 128, 128)
        label = "#{att.name} — #{att.file.filename}"
        canvas.text(label, at: [20, imported.box.height - 15])
        pdf.pages << imported
      end
    ensure
      tempfile&.close
      tempfile&.unlink
    end
  end

  def append_image_attachment(pdf, att)
    tempfile = nil
    begin
      ext = File.extname(att.file.filename.to_s)
      tempfile = Tempfile.new(['attach', ext], binmode: true)
      att.file.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind

      page = pdf.pages.add
      canvas = page.canvas

      # Add label at top
      canvas.font('Helvetica', size: 9)
      canvas.fill_color(128, 128, 128)
      label = "Attachment: #{att.name} — #{att.file.filename}"
      canvas.text(label, at: [20, page.box.height - 20])

      # Load and draw image
      begin
        image = pdf.images.add(tempfile.path)
        iw = image.info.width.to_f
        ih = image.info.height.to_f

        if iw <= 0 || ih <= 0
          raise "Invalid image dimensions"
        end

        # Available area (leave margins)
        margin = 30
        avail_w = page.box.width - (2 * margin)
        avail_h = page.box.height - 50  # account for label

        # Scale to fit
        scale = [avail_w / iw, avail_h / ih].min
        w = iw * scale
        h = ih * scale

        # Center
        x = (page.box.width - w) / 2.0
        y = margin + (avail_h - h) / 2.0

        canvas.image(image, at: [x, y + h], width: w, height: h)
      rescue => e
        Rails.logger.warn("Image embed failed for #{att.file.filename}: #{e.message}")
        canvas.font('Helvetica', size: 12)
        canvas.fill_color(100, 100, 100)
        canvas.text("[ Image could not be rendered: #{att.file.filename} ]", at: [60, page.box.height / 2])
      end
    ensure
      tempfile&.close
      tempfile&.unlink
    end
  end

  def append_other_attachment(pdf, att)
    page = pdf.pages.add
    canvas = page.canvas

    canvas.font('Helvetica', size: 14)
    canvas.fill_color(80, 80, 80)
    cx = page.box.width / 2

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

    canvas.font('Helvetica', size: 14)
    canvas.fill_color(180, 60, 60)
    canvas.text("Error Including Attachment", at: [50, page.box.height - 60])

    canvas.font('Helvetica', size: 12)
    canvas.fill_color(100, 100, 100)
    canvas.text("Could not include: #{att.file.filename}", at: [50, page.box.height - 100])
    canvas.text(att.name, at: [50, page.box.height - 122])
    canvas.text("Error: #{error_msg}", at: [50, page.box.height - 150])
  end

  def number_to_human_size(bytes)
    return '0 Bytes' if bytes.nil? || bytes.zero?
    
    units = %w[Bytes KB MB GB TB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp >= units.length
    size = bytes.to_f / (1024 ** exp)
    
    format("%.1f %s", size, units[exp])
  end
end
