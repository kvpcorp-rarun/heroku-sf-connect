require 'active_support/concern'
require 'benchmark'

module SfDbSync
  module SfDbSync  
    extend ActiveSupport::Concern
    
    module ClassMethods    
      # Optionally holds the value to determine if salesforce syncing is enabled. Defaults to true. If set 
      # to false syncing will be disabled for the class
      attr_accessor :sf_db_sync_enabled

      # Hash mapping of Salesforce attributes to web attributes
      # Example:
      # { :Email => :login, :FirstName => :first_name, :LastName => :last_name }
      #
      # "Web" attributes can be actual method names to return a custom value
      # If you are providing a method name to return a value, you should also implement a corresponding my_method_changed? to 
      # return if the value has changed.  Otherwise it will always be synced.
      attr_accessor :sf_db_sync_attribute_mapping
        
      # Returns an array of Salesforce attributes which should be synced asynchronously
      # Example:  ["Last_Login_Date__c", "Login_Count__c" ]
      # Note:  The model will fall back to synchronous sync if non-synchronous attributes are changed along with async attributes
      attr_accessor :salesforce_async_attributes
        
      # Returns a hash of default attributes that should be used when we are creating a new record
      attr_accessor :salesforce_default_attributes_for_create

      # Returns the "Id" attribute of the corresponding Salesforce object
      attr_accessor :salesforce_id_attribute_name

      # Returns the name of the Web Objects class. A custom value can be provided if you wish
      # to sync to a SF object and back to a different web object.  This would generally be used
      # if you wanted to flatten a web object into a larger SF object like Contact     
      attr_accessor :salesforce_web_class_name

      attr_accessor :salesforce_web_id_attribute_name        
      attr_accessor :sf_db_sync_web_id
      
      # Optionally holds the name of a method which will return the name of the Salesforce object to sync to
      attr_accessor :salesforce_object_name_method

      # Optionally holds the name of a method which can contain logic to determine if a record should be synced on save.
      # If no method is given then only the salesforce_skip_sync attribute is used.
      attr_accessor :salesforce_skip_sync_method
      
      # Accepts values from an outbound message hash and will either update an existing record OR create a new record
      # Firstly attempts to find an object by the salesforce_id attribute
      # Secondly attempts to look an object up by it's ID (WebId__c in outbound message)
      # Lastly it will create a new record setting it's salesforce_id
      def salesforce_update(attributes={})
        raise ArgumentError, "#{salesforce_id_attribute_name} parameter required" if attributes[salesforce_id_attribute_name].blank?

        object = self.unscoped.find_by_salesforce_id attributes[salesforce_id_attribute_name]
        object ||= self.unscoped.find_by_id attributes[salesforce_web_id_attribute_name] if sf_db_sync_web_id? && attributes[salesforce_web_id_attribute_name]
        
        if object.nil?
          object = self.new
          salesforce_default_attributes_for_create.merge(:salesforce_id => attributes[salesforce_id_attribute_name]).each_pair do |k, v|
            object.send("#{k}=", v)
          end
        end

        object.salesforce_process_update(attributes) if object && (object.salesforce_updated_at.nil? || (object.salesforce_updated_at && object.salesforce_updated_at < Time.parse(attributes[:SystemModstamp])))
      end
    end

    # if this instance variable is set to true, the sf_db_sync method will return without attempting
    # to sync data to Salesforce
    attr_accessor :salesforce_skip_sync
    
    # Salesforce completely excludes any empty/null fields from Outbound Messages
    # We initialize all declared attributes as nil before mapping the values from the message
    def salesforce_empty_attributes
      {}.tap do |hash|
        self.class.sf_db_sync_attribute_mapping.each do |key, value|
          hash[key] = nil
        end
      end
    end

    # An internal method used to get a hash of values that we are going to set from a Salesforce outbound message hash
    def salesforce_attributes_to_set(attributes = {})
      {}.tap do |hash| 
        # loop through the hash of attributes from the outbound message, and compare to our sf mappings and 
        # create a reversed hash of value's and key's to pass to update_attributes
        attributes.each do |key, value|
          # make sure our sync_mapping contains the salesforce attribute AND that our object has a setter for it
          hash[self.class.sf_db_sync_attribute_mapping[key.to_s].to_sym] = value if self.class.sf_db_sync_attribute_mapping.include?(key.to_s) && self.respond_to?("#{self.class.sf_db_sync_attribute_mapping[key.to_s]}=")
        end

        # remove the web_id from hash if it exists, as we don't want to modify a web_id
        hash.delete(:id)

        # update the sf_updated_at field with the system mod stamp from sf
        hash[:salesforce_updated_at] = attributes[:SystemModstamp]

        # incase we looked up via the WebId__c, we should set the salesforce_id
        hash[:salesforce_id] = attributes[self.class.salesforce_id_attribute_name]
      end
    end

    # Gets passed the Salesforce outbound message hash of changed values and updates the corresponding model
    def salesforce_process_update(attributes = {})
      attributes_to_update = salesforce_attributes_to_set(self.new_record? ? attributes : salesforce_empty_attributes.merge(attributes)) # only merge empty attributes for updates, so we don't overwrite the default create attributes

      puts "Attributes from outbound: #{attributes_to_update}"
      attributes_to_update.each_pair do |k, v|
        self.send("#{k}=", v)
      end
      
      # we don't want to keep going in a endless loop.  SF has just updated these values.
      self.salesforce_skip_sync = true 
      self.save(:validate => false)
    end

#    def salesforce_object_exists?
#      return salesforce_object_exists_method if respond_to? salesforce_exists_method
#      return salesforce_object_exists_default
#    end
    
    
    # Finds a salesforce record by its Id and returns nil or its SystemModstamp
    def system_mod_stamp
      hash = JSON.parse(SF_CLIENT.http_get("/services/data/v#{SF_CLIENT.version}/query", :q => "SELECT SystemModstamp FROM #{salesforce_object_name} WHERE Id = '#{salesforce_id}'").body)
      hash["records"].first.try(:[], "SystemModstamp")    
    end


    def salesforce_object_exists?
      return @exists_in_salesforce if @exists_in_salesforce
      # existing in salesfore is defined by the presence of salesforce_id attribute
      if has_salesforce_id?
        @exists_in_salesforce = true
      else
        @exists_in_salesforce = false
      end
    end

    # Checks if the passed in attribute should be updated in Salesforce.com
    def salesforce_should_update_attribute?(attribute)
      !self.respond_to?("#{attribute}_changed?") || (self.respond_to?("#{attribute}_changed?") && self.send("#{attribute}_changed?"))
    end

    # create a hash of updates to send to salesforce
    def salesforce_attributes_to_update(include_all = false)
      {}.tap do |hash| 
        self.class.sf_db_sync_attribute_mapping.each do |key, value|
          if self.respond_to?(value)

            #Checkboxes in SFDC Cannot be nil.  Here we check for boolean field type and set nil values to be false
            attribute_value = self.send(value)
            if is_boolean?(value) && attribute_value.nil?
              attribute_value = false
            end

            hash[key] = attribute_value if include_all || salesforce_should_update_attribute?(value)
          end
        end
      end    
    end

    def is_boolean?(attribute)
      self.column_for_attribute(attribute) && self.column_for_attribute(attribute).type == :boolean
    end

    def salesforce_create_object(attributes)
      attributes.merge!(self.class.salesforce_web_id_attribute_name.to_s => id) if self.class.sf_db_sync_web_id? && !new_record?
      puts "create #{Process.pid} #{attributes}"
      result = SF_CLIENT.http_post("/services/data/v#{SF_CLIENT.version}/sobjects/#{salesforce_object_name}", attributes.to_json)
      self.salesforce_id = JSON.parse(result.body)["id"]
      self.salesforce_skip_sync = true
      self.save
      @exists_in_salesforce = true
    end

    def salesforce_update_object(attributes)
      attributes.merge!(self.class.salesforce_web_id_attribute_name.to_s => id) if self.class.sf_db_sync_web_id? && !new_record?
      attributes.delete(self.class.salesforce_id_attribute_name.to_s)
      puts "update #{Process.pid} #{attributes}"
      raise "Salesforce ID not present to update" if salesforce_id.nil?
      SF_CLIENT.http_patch("/services/data/v#{SF_CLIENT.version}/sobjects/#{salesforce_object_name}/#{salesforce_id}", attributes.to_json)
    end

    # if attributes specified in the async_attributes array are the only attributes being modified, then sync the data 
    # via delayed_job
    def salesforce_perform_async_call?
      return false if salesforce_attributes_to_update.empty? || self.class.salesforce_async_attributes.empty?
      salesforce_attributes_to_update.keys.all? {|key| self.class.salesforce_async_attributes.include?(key) } && salesforce_id.present?
    end

    def salesforce_async_create
      return if self.salesforce_skip_sync? || has_salesforce_id?
      Delayed::Job.enqueue(::SfDbSync::SalesforceAsyncSync.new(self.class.salesforce_web_class_name, self.id, false))
    end

    def salesforce_async_update
      return if self.salesforce_skip_sync?
      Delayed::Job.enqueue(::SfDbSync::SalesforceAsyncSync.new(self.class.salesforce_web_class_name, self.id, true))
    end

    # sync model data to Salesforce, adding any Salesforce validation errors to the models errors
    # def sf_db_sync
    #   return if (self.salesforce_skip_sync? || has_salesforce_id_and_is_insert?)
    #   #if salesforce_perform_async_call?
    #   #  Delayed::Job.enqueue(SfDbSync::SalesforceObjectSync.new(self.class.salesforce_web_class_name, salesforce_id, salesforce_attributes_to_update), :priority => 50)
    #   #else
    #     Benchmark.bm(7) do |report|
    #       if salesforce_object_exists?
    #         #report.report("Salesforce Update:") { salesforce_update_object(salesforce_attributes_to_update) if salesforce_attributes_to_update.present? }
    #         Delayed::Job.enqueue(SfDbSync::SalesforceAsyncSync.new(self.class.salesforce_web_class_name, self.id, true))
    #       else
    #         #report.report("Salesforce Create:") { salesforce_create_object(salesforce_attributes_to_update(!new_record?)) if salesforce_id.nil? }
    #         Delayed::Job.enqueue(SfDbSync::SalesforceAsyncSync.new(self.class.salesforce_web_class_name, self.id, false))
    #       end
    #     end
    #     true
    #   #end
    # rescue Exception => ex
    #   puts ex.message
    #   puts ex.backtrace.join('\r\n')
    #   self.errors[:base] << ex.message
    #   return false
    # end

    def has_salesforce_id_and_is_insert?
      has_salesforce_id? && self.new_record?
      # FIXME - Always returning false
      false
    end

    def has_salesforce_id?
      self.salesforce_id.present?
    end
    
    def sync_web_id 	
      return false if !self.class.sf_db_sync_web_id? || self.salesforce_skip_sync?
      SF_CLIENT.http_patch("/services/data/v#{SF_CLIENT.version}/sobjects/#{salesforce_object_name}/#{salesforce_id}", { self.class.salesforce_web_id_attribute_name.to_s => id }.to_json) if salesforce_id
    end

    def salesforce_destroy
      return if self.salesforce_skip_sync?
      
      if self.salesforce_id.nil?
        raise "Salesforce ID not present to delete"
      else
        begin
          SF_CLIENT.http_delete("/services/data/v#{SF_CLIENT.version}/sobjects/#{salesforce_object_name}/#{salesforce_id}")
        rescue Exception => exception
          # If the entity is already deleted from salesforce delete from the PG too.
          if exception.message == "entity is deleted"
            puts "deleting #{self.class.name} with id #{self.id} from PG because, the entity is deleted from salesforce"
            true
          else
            raise exception
          end
        end
      end
    end

  end
end
