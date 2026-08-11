RSpec.configure do |config|
  config.around(:each) do |example|
    ActsAsTenant.current_tenant = nil
    example.run
    ActsAsTenant.current_tenant = nil
  end
end
