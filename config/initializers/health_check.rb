# frozen_string_literal: true

# Start the health check job chain when the application boots
Rails.application.config.after_initialize do
  # Only start in server mode, not in console or rake tasks
  if defined?(Rails::Server)
    Rails.logger.info "[Shelfarr] Starting HealthCheckJob chain"
    HealthCheckJob.perform_later
  end
rescue => e
  # Don't crash the app if there's an issue starting the health check
  Rails.logger.error "[Shelfarr] Failed to start HealthCheckJob: #{e.message}"
end
