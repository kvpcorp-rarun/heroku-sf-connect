class Account < ActiveRecord::Base
	 # Sync Attributes
  sf_db_syncable :sync_attributes => {
  	                    :Rails_ID__c                         => :id,
                        :Sync_First_Name__c                  => :first_name,
                        :Id                                  => :salesforce_id
                        },:salesforce_object_name => :salesforce_object_name,
                        :web_id_attribute_name => :Rails_ID__c

  def salesforce_object_name
    "Account"
  end
end
