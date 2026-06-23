# frozen_string_literal: true

# Schedule IBCOS XML sync every 2 hours
Rails.application.config.after_initialize do
  if defined?(Sidekiq) && Sidekiq.server?
    # Start the recurring sync job (runs immediately, then every 2 hours)
    # The job will reschedule itself automatically
    IbcosXmlSyncJob.perform_later(reschedule: true)
    
    Rails.logger.info 'IBCOS XML sync scheduler initialized - syncing every 2 hours'
  end
end
