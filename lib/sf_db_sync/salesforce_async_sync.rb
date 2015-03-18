module SfDbSync
  # A class to sync every thing asynchronously to salesforce
  class SalesforceAsyncSync < Struct.new(:web_object_name, :id, :update)
    def perform
      record = web_object_name.constantize.unscoped.find(id) 
      if update
        record.salesforce_update_object(record.salesforce_attributes_to_update(true))
      else
        record.salesforce_create_object(record.salesforce_attributes_to_update(true))
      end
    end

    def reschedule_at(time, attempts)
      if is_waiting_on_association?
        2.seconds.from_now
      else
        time + (attempts ** 1.4) + 5
      end
    end

    def max_attempts
      if is_waiting_on_association?
        50
      else
        Delayed::Worker.max_attempts
      end
    end

    # On error store the exception in an instance variable
    # and use it to calculate reschedule_at
    def error(job, exception)
      @exception = exception
    end

    # On failure, send an exception email to developers
    def failure(job)
      SyncFailureMailer.failure(job.id).deliver
    end

    private

    def is_waiting_on_association?
      @exception.message == "salesforce association not found"
    end
  end
end
