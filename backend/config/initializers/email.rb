# frozen_string_literal: true

# Email delivery configuration
# Development: letter_opener_web (captured at /letter_opener)
# Production: SMTP via environment variables (SendGrid, Mailgun, SES)
if Rails.env.production? && ENV["SMTP_ADDRESS"].present?
  Rails.application.config.action_mailer.delivery_method = :smtp
  Rails.application.config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    domain: ENV.fetch("SMTP_DOMAIN", "mentorbook.io"),
    user_name: ENV.fetch("SMTP_USERNAME"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: :plain,
    enable_starttls_auto: true
  }
end
