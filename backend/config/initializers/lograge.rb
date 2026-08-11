# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Include additional fields in each log entry
  config.lograge.custom_options = lambda do |event|
    {
      correlation_id: RequestStore.store[:correlation_id],
      user_id: RequestStore.store[:user_id],
      org_id: RequestStore.store[:org_id],
      time: Time.current.utc.iso8601
    }
  end

  # Include params (filtered)
  config.lograge.custom_payload do |controller|
    {
      params: controller.request.filtered_parameters.except("controller", "action")
    }
  end
end
