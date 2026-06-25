# frozen_string_literal: true

# Find the native wkhtmltopdf binary (not the Ruby wrapper) to avoid setuid issues
native_bin = Dir.glob('/usr/local/bundle/gems/wkhtmltopdf-binary-*/bin/wkhtmltopdf_linux_*').find { |f|
  File.file?(f) && !f.end_with?('.rb')
}

WickedPdf.configure do |config|
  config.exe_path = native_bin || '/usr/local/bundle/bin/wkhtmltopdf'
end
