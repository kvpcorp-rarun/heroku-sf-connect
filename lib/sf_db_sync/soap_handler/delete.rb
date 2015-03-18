module SfDbSync
  module SoapHandler
    class Delete < ::SfDbSync::SoapHandler::Base
       def process_notifications(priority = 90)
         batch_process do |sobject|
           ::SfDbSync::SoapHandler::Delete.__delay__(:priority => priority, :run_at => 5.seconds.from_now).delete_object(sobject)
         end
       end

       def self.delete_object(hash = {})
         puts "Delete hash contains: #{hash}"
         raise ArgumentError, "Object_Id__c parameter required" if hash[namespaced(:Object_Id__c)].blank?
         raise ArgumentError, "Object_Type__c parameter required" if hash[namespaced(:Object_Type__c)].blank?
     
         object = hash[namespaced(:Object_Type__c)].constantize.find_by_salesforce_id(hash[namespaced(:Object_Id__c)])
         object.delete if object
       end
    end
   end
 end
