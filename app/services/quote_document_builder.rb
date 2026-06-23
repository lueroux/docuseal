# frozen_string_literal: true

class QuoteDocumentBuilder
  attr_reader :quote

  def initialize(quote)
    @quote = quote
  end

  def build_html
    sections = quote.quote_sections.visible.ordered
    
    html_parts = []
    html_parts << build_cover_page
    
    # Always show products if they exist
    if quote.quote_items.any?
      # Check if there's already a pricing section
      has_pricing_section = sections.any? { |s| s.section_type == 'pricing' }
      html_parts << build_pricing_table(nil) unless has_pricing_section
    end
    
    sections.each do |section|
      html_parts << case section.section_type
                    when 'spec_sheet'
                      build_spec_sheet(section)
                    when 'pricing'
                      build_pricing_table(section)
                    when 'terms'
                      build_terms_section(section)
                    when 'attachment'
                      build_attachment_section(section)
                    else
                      build_custom_section(section)
                    end
    end
    
    html_parts.compact.join("\n")
  end

  private

  def build_cover_page
    date_line = "Date: #{quote.created_at.strftime('%d %B %Y')}"
    date_line += " | Valid Until: #{quote.valid_until.strftime('%d %B %Y')}" if quote.valid_until.present?
    
    customer_section = if quote.customer.company.present?
      <<~HTML
        <div class="customer-details">
          <h2>Customer Details</h2>
          <p><strong>#{quote.customer.company.name}</strong></p>
          <p class="attention-of">Attention: #{quote.customer.name}</p>
          <p>#{quote.customer.email}</p>
          #{quote.customer.phone.present? ? "<p>#{quote.customer.phone}</p>" : ''}
        </div>
      HTML
    else
      <<~HTML
        <div class="customer-details">
          <h2>Customer Details</h2>
          <p><strong>#{quote.customer.name}</strong></p>
          <p>#{quote.customer.email}</p>
          #{quote.customer.phone.present? ? "<p>#{quote.customer.phone}</p>" : ''}
        </div>
      HTML
    end
    
    <<~HTML
      <div class="cover-page page-break">
        <div class="cover-header">
          <h1>#{quote.title || 'Quote'}</h1>
          <p class="reference">Reference: #{quote.reference_number}</p>
          <p class="date">#{date_line}</p>
        </div>
        
        #{customer_section}
        
        #{quote.notes.present? ? "<div class='quote-notes'><h2>Notes</h2><p>#{simple_format(quote.notes)}</p></div>" : ''}
      </div>
    HTML
  end

  def build_spec_sheet(section)
    <<~HTML
      <div class="spec-sheet-section page-break">
        <h2>#{section.title || 'Specifications'}</h2>
        #{render_spec_content(section.content)}
      </div>
    HTML
  end

  def build_pricing_table(section)
    items_html = quote.quote_items.ordered.map do |item|
      build_item_row(item)
    end.join("\n")

    subtotal = quote.quote_items.sum { |item| item.total_with_options }
    vat = subtotal * 0.20
    total = subtotal + vat

    section_title = section&.title || 'Pricing'

    <<~HTML
      <div class="pricing-section page-break">
        <h2>#{section_title}</h2>
        <table class="pricing-table">
          <thead>
            <tr>
              <th>Item</th>
              <th>Quantity</th>
              <th>Unit Price</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            #{items_html}
          </tbody>
          <tfoot>
            <tr>
              <td colspan="3" class="text-right"><strong>Subtotal:</strong></td>
              <td>£#{number_with_precision(subtotal, precision: 2)}</td>
            </tr>
            <tr>
              <td colspan="3" class="text-right"><strong>VAT (20%):</strong></td>
              <td>£#{number_with_precision(vat, precision: 2)}</td>
            </tr>
            <tr class="total-row">
              <td colspan="3" class="text-right"><strong>Total:</strong></td>
              <td><strong>£#{number_with_precision(total, precision: 2)}</strong></td>
            </tr>
          </tfoot>
        </table>
      </div>
    HTML
  end

  def build_item_row(item)
    options_html = if item.quote_item_options.selected.any?
                     option_list = item.quote_item_options.selected.map { |opt| "#{opt.name} (+£#{number_with_precision(opt.price, precision: 2)})" }.join(', ')
                     "<div class='item-options'>Options: #{option_list}</div>"
                   else
                     ''
                   end

    <<~HTML
      <tr>
        <td>
          <strong>#{item.product.name}</strong>
          <div class="item-sku">SKU: #{item.product.sku}</div>
          #{options_html}
          #{item.notes.present? ? "<div class='item-notes'>#{item.notes}</div>" : ''}
        </td>
        <td>#{item.quantity}</td>
        <td>£#{number_with_precision(item.quoted_price, precision: 2)}</td>
        <td>£#{number_with_precision(item.total_with_options, precision: 2)}</td>
      </tr>
    HTML
  end

  def build_terms_section(section)
    <<~HTML
      <div class="terms-section page-break">
        <h2>#{section.title || 'Terms & Conditions'}</h2>
        <div class="terms-content">
          #{section.content['html'] || '<p>Standard terms and conditions apply.</p>'}
        </div>
      </div>
    HTML
  end

  def build_attachment_section(section)
    <<~HTML
      <div class="attachment-section">
        <h3>#{section.title}</h3>
        <p>#{section.content['description']}</p>
      </div>
    HTML
  end

  def build_custom_section(section)
    <<~HTML
      <div class="custom-section">
        <h2>#{section.title}</h2>
        <div>#{section.content['html'] || section.content['text']}</div>
      </div>
    HTML
  end

  def render_spec_content(content)
    return '' if content.blank?

    html = []
    
    if content['specs'].present?
      html << '<table class="specs-table">'
      content['specs'].each do |key, value|
        html << "<tr><th>#{key}</th><td>#{value}</td></tr>"
      end
      html << '</table>'
    end

    if content['features'].present?
      html << '<h3>Features</h3>'
      html << '<ul class="features-list">'
      content['features'].each do |feature|
        html << "<li>#{feature}</li>"
      end
      html << '</ul>'
    end

    html.join("\n")
  end

  def simple_format(text)
    text.to_s.gsub(/\r\n?/, "\n").split(/\n\n+/).map { |t| "<p>#{t.gsub(/\n/, '<br>')}</p>" }.join
  end

  def number_with_precision(number, precision: 2)
    format("%.#{precision}f", number)
  end
end
