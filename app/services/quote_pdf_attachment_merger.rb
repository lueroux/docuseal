# frozen_string_literal: true

require 'hexapdf'
require 'tempfile'

class QuotePdfAttachmentMerger
  attr_reader :base_pdf_data, :quote

  def initialize(base_pdf_data, quote)
    @base_pdf_data = base_pdf_data
    @quote = quote
  end

  def merge
    return base_pdf_data unless quote.quote_attachments.ordered.any?

    begin
      pdf = HexaPDF::Document.open(StringIO.new(base_pdf_data))

      quote.quote_attachments.ordered.each do |att|
        append_attachment(pdf, att)
      end

      io = StringIO.new
      pdf.write(io)
      io.string
    rescue => e
      Rails.logger.error("Attachment merging failed: #{e.message}, falling back to base PDF")
      Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
      base_pdf_data
    end
  end

  private

  def append_attachment(pdf, att)
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

      begin
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
        Rails.logger.warn("Image embed failed: #{e.message}")
        canvas.font('Helvetica', size: 12)
        canvas.fill_color(100, 100, 100)
        canvas.text("[ Image could not be rendered: #{att.file.filename} ]", at: [60, page.box.height / 2])
      end
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
    canvas.text("(This file type cannot be displayed inline)", at: [cx - 130, page.box.height - 280])
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
  end

  def number_to_human_size(bytes)
    return '0 Bytes' if bytes.nil? || bytes.zero?
    units = %w[Bytes KB MB GB TB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp >= units.length
    format("%.1f %s", bytes.to_f / (1024 ** exp), units[exp])
  end
end
