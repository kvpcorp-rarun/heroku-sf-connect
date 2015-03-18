module SfDbSync
  module SoapHandler
    class Base
      attr_reader :xml_hashed, :options, :sobjects

      def initialize request_body, sobject_name
        xml_hashed         = Hash.from_xml(request_body)
        xml_hashed[:klass] = sobject_name
        puts "Outbound came as: #{xml_hashed}"
        @options = xml_hashed
        @xml_hashed = xml_hashed
        @organization = ::SfDbSync.config["ORGANIZATION_ID"]
        @sobjects = collect_sobjects if valid?
      end

      # queues each individual record from the message for update
      def process_notifications(priority = 90)
        batch_process do |sobject|
          options[:klass].camelize.constantize.__delay__(:priority => priority, :run_at => Time.now).salesforce_update(sobject)
        end
      end

      # ensures that the received message is properly formed, and that it comes from the expected Salesforce Org
      def valid?
        notifications = @xml_hashed.try(:[], "Envelope").try(:[], "Body").try(:[], "notifications")

        organization_id = notifications.try(:[], "OrganizationId")
        puts "#{!notifications.try(:[], "Notification").nil?} && #{organization_id == @organization}"
        return !notifications.try(:[], "Notification").nil? && organization_id == @organization # we sent this to ourselves
      end

      def batch_process(&block)
        return if sobjects.nil? || !block_given?
        sobjects.each do | sobject |
          yield sobject
        end
      end

      #xml for SFDC response
      #called from soap_message_controller
      def generate_response(error = nil)      
        response = "<Ack>#{sobjects.nil? ? false : true}</Ack>" unless error
        if error 
          response = "<soapenv:Fault><faultcode>soap:Receiver</faultcode><faultstring>#{error.message}</faultstring></soapenv:Fault>"
        end
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?><soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><soapenv:Body><notificationsResponse>#{response}</notificationsResponse></soapenv:Body></soapenv:Envelope>"
      end

      def self.namespaced(field)
         ::SfDbSync.config["NAMESPACE_PREFIX"].present? ? :"#{::SfDbSync.config["NAMESPACE_PREFIX"]}__#{field}" : :"#{field}"
      end
    
      private

      def collect_sobjects
        notification = @xml_hashed["Envelope"]["Body"]["notifications"]["Notification"] 
        if notification.is_a? Array
          return notification.collect{ |h| h["sObject"].symbolize_keys}
        else
          return [notification["sObject"].try(:symbolize_keys)]
        end
      end
    end
  end
end
