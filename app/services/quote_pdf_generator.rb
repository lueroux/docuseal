# frozen_string_literal: true

require 'hexapdf'

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
    
    # Output PDF
    io = StringIO.new
    pdf.write(io)
    io.string
  end
end
