# frozen_string_literal: true

class QuoteDocumentBuilder
  attr_reader :quote

  def initialize(quote)
    @quote = quote
  end

  def build_html
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Quotation #{quote.reference_number} — Buxtons</title>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
        #{build_styles}
      </head>
      <body>
        <div class="document">
          #{build_header}
          #{build_title}
          #{build_meta_section}
          #{build_description if quote.notes.present?}
          #{build_items_table}
          #{build_totals}
          #{build_disclaimer}
          #{build_signature_section}
        </div>
        #{build_product_details}
      </body>
      </html>
    HTML
  end

  private

  def build_styles
    <<~CSS
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Inter', Arial, sans-serif; font-size: 13px; color: #242424; background: #e5e5e5; padding: 32px 16px; }
        .document { width: 794px; min-height: 1123px; margin: 0 auto; padding: 56px 64px 48px; position: relative; }
        :root { --green: #94be57; --green-dark: #7aa844; --grey-light: #f4f4f4; --grey-mid: #c8c8c8; --text-dark: #242424; --text-muted: #666666; }
        .uppercase { text-transform: uppercase; }
        .text-right { text-align: right; }
        .font-medium { font-weight: 500; }
        .font-semibold { font-weight: 600; }
        .font-bold { font-weight: 700; }
        .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 32px; }
        .logo-area img { max-height: 72px; max-width: 200px; object-fit: contain; }
        .company-address { text-align: right; font-size: 11.5px; font-weight: 500; letter-spacing: 0.06em; line-height: 1.7; text-transform: uppercase; color: var(--text-dark); }
        .company-address a { color: inherit; text-decoration: none; }
        .document-title { font-size: 28px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; text-align: center; color: var(--text-dark); margin-bottom: 24px; border-bottom: 3px solid var(--green); padding-bottom: 14px; }
        .meta-row { display: flex; justify-content: space-between; gap: 24px; margin-bottom: 28px; }
        .client-block { flex: 1; }
        .block-label { font-size: 10px; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; color: var(--text-muted); margin-bottom: 6px; }
        .client-name { font-size: 15px; font-weight: 600; margin-bottom: 4px; color: var(--text-dark); }
        .client-details { font-size: 12px; line-height: 1.7; color: var(--text-dark); }
        .quote-details-block { flex: 0 0 240px; background: var(--grey-light); padding: 16px 20px; }
        .quote-details-block table { width: 100%; border-collapse: collapse; }
        .quote-details-block td { padding: 3px 0; font-size: 12px; line-height: 1.5; }
        .quote-details-block td:first-child { font-weight: 600; color: var(--text-muted); white-space: nowrap; padding-right: 12px; text-transform: uppercase; font-size: 10.5px; letter-spacing: 0.05em; }
        .quote-details-block td:last-child { font-weight: 500; color: var(--text-dark); }
        .description-block { background: var(--grey-light); border-left: 4px solid var(--green); padding: 14px 18px; margin-bottom: 28px; font-size: 12.5px; line-height: 1.7; color: var(--text-dark); }
        .items-table { width: 100%; border-collapse: collapse; margin-bottom: 8px; font-size: 12.5px; }
        .items-table thead tr { background: var(--green); color: #ffffff; }
        .items-table thead th { padding: 10px 14px; font-weight: 600; letter-spacing: 0.06em; text-transform: uppercase; font-size: 11px; }
        .items-table thead th:first-child { text-align: left; }
        .items-table thead th:not(:first-child) { text-align: right; }
        .items-table tbody tr:nth-child(odd) { background: #ffffff; }
        .items-table tbody tr:nth-child(even) { background: var(--grey-light); }
        .items-table tbody td { padding: 10px 14px; line-height: 1.5; vertical-align: top; }
        .items-table tbody td:not(:first-child) { text-align: right; }
        .totals-wrapper { display: flex; justify-content: flex-end; margin-bottom: 28px; }
        .totals-table { width: 280px; border-collapse: collapse; font-size: 12.5px; }
        .totals-table td { padding: 7px 14px; }
        .totals-table tr:not(.total-row) td:first-child { color: var(--text-muted); font-weight: 500; }
        .totals-table tr:not(.total-row) td:last-child { text-align: right; font-weight: 500; }
        .totals-table tr:not(.total-row):nth-child(odd) { background: var(--grey-light); }
        .totals-table .total-row { background: var(--green); color: #ffffff; }
        .totals-table .total-row td { font-weight: 700; font-size: 13.5px; letter-spacing: 0.04em; }
        .totals-table .total-row td:last-child { text-align: right; }
        .disclaimer { font-size: 11px; color: var(--text-muted); line-height: 1.7; border-top: 1px solid var(--grey-light); padding-top: 16px; margin-bottom: 24px; }
        .sign-terms-row { display: flex; justify-content: space-between; gap: 32px; margin-bottom: 0; }
        .signature-block { flex: 1; }
        .signature-line { border-bottom: 1.5px solid var(--text-dark); height: 44px; margin-bottom: 6px; }
        .signature-label { font-size: 11px; color: var(--text-muted); letter-spacing: 0.05em; }
        .date-signed-line { margin-top: 20px; }
        .terms-block { flex: 1; background: var(--grey-light); padding: 14px 18px; }
        .terms-block p { font-size: 12px; line-height: 1.6; color: var(--text-dark); margin-top: 8px; }
        .page-break { page-break-before: always; break-before: page; }
        .product-detail-page { margin-top: 1em; }
        .product-detail-title { font-size: 20px; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; text-align: center; color: var(--text-dark); margin-bottom: 20px; border-bottom: 2px solid var(--green); padding-bottom: 10px; }
        .product-detail-grid { display: flex; gap: 24px; margin-bottom: 20px; }
        .product-detail-image { flex: 0 0 300px; }
        .product-detail-image img { width: 100%; max-height: 280px; object-fit: contain; border: 1px solid var(--grey-mid); border-radius: 4px; }
        .product-detail-info { flex: 1; }
        .product-detail-info .product-name { font-size: 18px; font-weight: 700; margin-bottom: 8px; color: var(--text-dark); }
        .product-detail-info .product-meta { font-size: 12px; color: var(--text-muted); margin-bottom: 12px; line-height: 1.7; }
        .product-detail-info .product-meta strong { color: var(--text-dark); font-weight: 600; }
        .product-description { font-size: 12.5px; line-height: 1.7; color: var(--text-dark); margin-bottom: 20px; }
        .product-description p { margin-bottom: 8px; }
        .product-specs-title { font-size: 14px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; color: var(--text-dark); margin-bottom: 10px; border-bottom: 1px solid var(--grey-light); padding-bottom: 6px; }
        .product-specs-table { width: 100%; border-collapse: collapse; font-size: 12px; }
        .product-specs-table td { padding: 6px 10px; line-height: 1.5; }
        .product-specs-table tr:nth-child(odd) { background: var(--grey-light); }
        .product-specs-table td:first-child { font-weight: 600; color: var(--text-muted); white-space: nowrap; padding-right: 16px; }
        .product-specs-table td:last-child { color: var(--text-dark); }
        @media print {
          body { background: #ffffff; padding: 0; }
          .document { width: 100%; min-height: auto; box-shadow: none; padding: 20mm 18mm; margin: 0; }
          a { color: inherit; text-decoration: none; }
        }
      </style>
    CSS
  end

  def build_header
    <<~HTML
      <header class="header">
        <div class="logo-area">
          <img src="https://buxtons.net/wp-content/uploads/2025/02/buxtons-264x116.png" alt="Buxtons logo" />
        </div>
        <address class="company-address">
          Coppice House, Penkridge,<br>
          Staffordshire, ST19 5RP<br>
          <a href="https://www.buxtons.net">www.buxtons.net</a> / <a href="tel:01785712397">01785 712397</a>
        </address>
      </header>
    HTML
  end

  def build_title
    <<~HTML
      <h1 class="document-title">Quotation</h1>
    HTML
  end

  def build_meta_section
    customer = quote.customer
    customer_name = customer&.company.present? ? customer.company.name : customer&.name
    customer_address = customer ? format_address(customer) : ''
    
    <<~HTML
      <div class="meta-row">
        <div class="client-block">
          <div class="block-label">Prepared for</div>
          <div class="client-name">#{customer_name || 'Not specified'}</div>
          <div class="client-details">
            #{customer_address}
            #{customer&.phone.present? ? "<br>#{customer.phone}" : ''}
          </div>
        </div>
        <div class="quote-details-block">
          <table>
            <tbody>
              <tr>
                <td>Quotation No:</td>
                <td>#{quote.reference_number}</td>
              </tr>
              <tr>
                <td>Date:</td>
                <td>#{quote.created_at.strftime('%d/%m/%Y')}</td>
              </tr>
              <tr>
                <td>Valid Until:</td>
                <td>#{quote.valid_until&.strftime('%d/%m/%Y') || 'N/A'}</td>
              </tr>
              <tr>
                <td>Prepared By:</td>
                <td>#{quote.user.first_name} #{quote.user.last_name}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    HTML
  end

  def build_description
    <<~HTML
      <div class="description-block">
        <p>#{simple_format(quote.notes)}</p>
      </div>
    HTML
  end

  def build_items_table
    return '' unless quote.quote_items.any?
    
    items_html = quote.quote_items.ordered.map do |item|
      build_item_row(item)
    end.join("\n")

    <<~HTML
      <table class="items-table">
        <thead>
          <tr>
            <th scope="col">Description</th>
            <th scope="col">Quantity</th>
            <th scope="col">Price</th>
            <th scope="col">Total</th>
          </tr>
        </thead>
        <tbody>
          #{items_html}
        </tbody>
      </table>
    HTML
  end

  def build_item_row(item)
    description_parts = ["<strong>#{item.product.name}</strong>"]
    description_parts << "<div style='font-size: 11px; color: #666; margin-top: 2px;'>SKU: #{item.product.sku}</div>"
    
    if item.quote_item_options.where(is_selected: true).any?
      options_list = item.quote_item_options.where(is_selected: true).map { |opt| opt.name }.join(', ')
      description_parts << "<div style='font-size: 11px; margin-top: 4px;'><em>Options: #{options_list}</em></div>"
    end
    
    if item.notes.present?
      description_parts << "<div style='font-size: 11px; color: #666; margin-top: 4px;'>#{item.notes}</div>"
    end

    <<~HTML
      <tr>
        <td>#{description_parts.join}</td>
        <td>#{item.quantity}</td>
        <td>£#{number_with_precision(item.quoted_price, precision: 2)}</td>
        <td>£#{number_with_precision(item.line_total, precision: 2)}</td>
      </tr>
    HTML
  end

  def build_totals
    subtotal = quote.quote_items.sum { |item| item.line_total }
    vat = subtotal * 0.20
    total = subtotal + vat

    <<~HTML
      <div class="totals-wrapper">
        <table class="totals-table">
          <tbody>
            <tr>
              <td>Subtotal</td>
              <td>£#{number_with_precision(subtotal, precision: 2)}</td>
            </tr>
            <tr>
              <td>VAT (20%)</td>
              <td>£#{number_with_precision(vat, precision: 2)}</td>
            </tr>
            <tr class="total-row">
              <td>Total</td>
              <td>£#{number_with_precision(total, precision: 2)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    HTML
  end

  def build_disclaimer
    <<~HTML
      <p class="disclaimer">
        Above information is not an invoice and only an estimate of goods/services.
        Payment will be due prior to provision or delivery of goods/services.
      </p>
    HTML
  end

  def build_signature_section
    <<~HTML
      <div class="sign-terms-row">
        <div class="signature-block">
          <div class="block-label">Acceptance</div>
          <div class="signature-line"></div>
          <p class="signature-label">Signature</p>
          <div class="signature-line date-signed-line"></div>
          <p class="signature-label">Date signed</p>
        </div>
        <div class="terms-block">
          <div class="block-label">Terms &amp; Conditions</div>
          <p>Please confirm your acceptance of this quote by signing and returning a copy.</p>
        </div>
      </div>
    HTML
  end

  def build_product_details
    return '' unless quote.quote_items.any?

    pages_html = quote.quote_items.ordered.map do |item|
      build_product_detail_page(item)
    end.join("\n")

    pages_html
  end

  def build_product_detail_page(item)
    product = item.product
    image_html = ''
    if product.image_url.present?
      image_html = "<div class=\"product-detail-image\"><img src=\"#{product.image_url}\" alt=\"#{product.name}\" /></div>"
    end

    meta_parts = []
    meta_parts << "<strong>SKU:</strong> #{product.sku}" if product.sku.present?
    meta_parts << "<strong>Brand:</strong> #{product.brand}" if product.brand.present?
    meta_parts << "<strong>Category:</strong> #{product.category}" if product.category.present?
    meta_parts << "<strong>Retail Price:</strong> &pound;#{number_with_precision(product.retail_price, precision: 2)}" if product.retail_price.present?
    meta_html = meta_parts.join(' &nbsp;|&nbsp; ')

    description_html = ''
    if product.short_description.present? || product.description.present?
      desc_parts = []
      desc_parts << "<p>#{product.short_description}</p>" if product.short_description.present?
      desc_parts << "<p>#{product.description}</p>" if product.description.present?
      description_html = "<div class=\"product-description\">#{desc_parts.join}</div>"
    end

    specs_html = ''
    spec_rows = []
    if product.spec_data.is_a?(Hash)
      product.spec_data.each do |key, value|
        next if value.blank?
        spec_rows << "<tr><td>#{key.to_s.humanize}</td><td>#{value}</td></tr>"
      end
    end
    if product.woo_attributes.is_a?(Hash)
      product.woo_attributes.each do |key, value|
        next if value.blank?
        next unless product.attribute_visible?(key)
        label = product.attribute_label(key)
        display_value = value.is_a?(Array) ? value.join(', ') : value
        spec_rows << "<tr><td>#{label}</td><td>#{display_value}</td></tr>"
      end
    end
    if spec_rows.any?
      specs_html = "<div class=\"product-specs-title\">Specifications</div><table class=\"product-specs-table\"><tbody>#{spec_rows.join}</tbody></table>"
    end

    <<~HTML
      <div class="document page-break product-detail-page">
        <h2 class="product-detail-title">Product Details</h2>
        <div class="product-detail-grid">
          #{image_html}
          <div class="product-detail-info">
            <div class="product-name">#{product.name}</div>
            <div class="product-meta">#{meta_html}</div>
          </div>
        </div>
        #{description_html}
        #{specs_html}
      </div>
    HTML
  end

  def format_address(customer)
    parts = []
    if customer.company.present? && customer.company.billing_address.present?
      addr = customer.company.billing_address
      parts << addr['line1'] if addr['line1'].present?
      parts << addr['line2'] if addr['line2'].present?
      parts << addr['city'] if addr['city'].present?
      parts << addr['postcode'] if addr['postcode'].present?
    elsif customer.billing_address.present?
      addr = customer.billing_address
      parts << addr['line1'] if addr['line1'].present?
      parts << addr['line2'] if addr['line2'].present?
      parts << addr['city'] if addr['city'].present?
      parts << addr['postcode'] if addr['postcode'].present?
    end
    parts.any? ? parts.join(',<br>') : customer.email
  end

  def simple_format(text)
    return '' if text.blank?
    text.to_s.gsub(/\r\n?/, "\n").split(/\n\n+/).map { |t| t.gsub(/\n/, '<br>') }.join('</p><p>')
  end

  def number_with_precision(number, precision: 2, delimiter: ',')
    # Format the number with precision
    formatted = format("%.#{precision}f", number)
    
    # Split into integer and decimal parts
    parts = formatted.split('.')
    
    # Add thousand separators to integer part
    parts[0].gsub!(/(\d)(?=(\d{3})+(?!\d))/, "\\1#{delimiter}")
    
    # Rejoin with decimal point
    parts.join('.')
  end
end
