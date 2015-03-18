# DelayedJob configuration
Delayed::Worker.destroy_failed_jobs     = false
Delayed::Worker.max_attempts            = 10
Delayed::Worker.logger                  = Logger.new(File.join(Rails.root, 'log', 'delayed_job.log'))
Delayed::Worker.raise_signal_exceptions = :term
