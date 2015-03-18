module SfDbSync
  module Extenders
    module SfDbSyncable      
      def sf_db_syncable(options = {})
        require 'sf_db_sync/sf_db_sync'
        include ::SfDbSync::SfDbSync

        self.sf_db_sync_enabled = options.has_key?(:sf_db_sync_enabled) ? options[:sf_db_sync_enabled] : true
        self.sf_db_sync_attribute_mapping = options.has_key?(:sync_attributes) ? options[:sync_attributes].stringify_keys : {}
        self.salesforce_async_attributes = options.has_key?(:async_attributes) ? options[:async_attributes] : {}
        self.salesforce_default_attributes_for_create = options.has_key?(:default_attributes_for_create) ? options[:default_attributes_for_create] : {}
        self.salesforce_id_attribute_name = options.has_key?(:salesforce_id_attribute_name) ? options[:salesforce_id_attribute_name] : :Id
        self.salesforce_web_id_attribute_name = options.has_key?(:web_id_attribute_name) ? options[:web_id_attribute_name] : :WebId__c
        self.sf_db_sync_web_id = options.has_key?(:sf_db_sync_web_id) ? options[:sf_db_sync_web_id] : false
        self.salesforce_web_class_name = options.has_key?(:web_class_name) ? options[:web_class_name] : self.name
        
        self.salesforce_object_name_method = options.has_key?(:salesforce_object_name) ? options[:salesforce_object_name] : nil
        self.salesforce_skip_sync_method = options.has_key?(:except) ? options[:except] : nil
        
        instance_eval do
          #after_save :sf_db_sync
          after_create :salesforce_async_create
          after_update :salesforce_async_update
          after_create :sync_web_id
          before_destroy :salesforce_destroy
                  
          def sf_db_sync_web_id?
            self.sf_db_sync_web_id
          end
        end
        
        class_eval do
          # Calls a method if provided to return the name of the Salesforce object the model is syncing to.
          # If no method is provided, defaults to the class name
          def salesforce_object_name
            return send(self.class.salesforce_object_name_method) if self.class.salesforce_object_name_method.present?
            return self.class.name
          end
          
          # Calls a method, if provided, to determine if a record should be synced to Salesforce. 
          # The salesforce_skip_sync instance variable is also used.
          # The SALESFORCE_AR_SYNC_ENABLED flag overrides all the others if set to false
          def salesforce_skip_sync?
            return true if ::SfDbSync.config["SYNC_ENABLED"] == false
            return (salesforce_skip_sync || !self.class.sf_db_sync_enabled || send(self.class.salesforce_skip_sync_method)) if self.class.salesforce_skip_sync_method.present?
            return (salesforce_skip_sync || !self.class.sf_db_sync_enabled)
          end
        end
      end
    end
  end
end
