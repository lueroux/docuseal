# frozen_string_literal: true

# Find the actual wkhtmltopdf binary, not the Ruby wrapper
wkhtmltopdf_binary = Dir.glob('/usr/local/bundle/gems/wkhtmltopdf-binary-*/bin/wkhtmltopdf_*').find { |f|
  File.file?(f) && File.executable?(f) && f.include?('linux')
}

WickedPdf.configure do |config|
  # Use the native binary directly to avoid Ruby setuid issues
  config.exe_path = wkhtmltopdf_binary || '/usr/local/bundle/bin/wkhtmltopdf'
end
