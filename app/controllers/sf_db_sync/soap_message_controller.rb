module SfDbSync
  class SoapMessageController < ::ApplicationController
    skip_before_filter :verify_authenticity_token
    before_filter :validate_ip_ranges
    
    def sync_object
      delayed_soap_handler ::SfDbSync::SoapHandler::Base
    end

    def delete
      delayed_soap_handler ::SfDbSync::SoapHandler::Delete
    end

    private

    def delayed_soap_handler (klass, priority = 90)
      begin
        soap_handler = klass.new(request.body.read, params['klass'])
        soap_handler.process_notifications(priority) if soap_handler.sobjects
        render :xml => soap_handler.generate_response, :status => :created
      rescue Exception => ex
        puts ex.message
        puts ex.backtrace
        render :xml => soap_handler.generate_response(ex), :status => :created
      end
    end

    # to be used in a before_filter, checks ip ranges specified in configuration
    # and renders a 404 unless the request matches
    def validate_ip_ranges
      raise ActionController::RoutingError.new('Not Found') unless ::SfDbSync::IPConstraint.new.matches?(request)
    end
  end
end
