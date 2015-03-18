require 'sf_db_sync/version'
require 'sf_db_sync/extenders/sf_db_syncable'
require 'sf_db_sync/salesforce_object_sync'
require 'sf_db_sync/salesforce_async_sync'
require 'sf_db_sync/soap_handler/base'
require 'sf_db_sync/soap_handler/delete'
require 'sf_db_sync/ip_constraint'

module SfDbSync
  mattr_accessor :app_root
  mattr_accessor :config
  
  def self.setup
    yield self
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend SfDbSync::Extenders::SfDbSyncable
end
