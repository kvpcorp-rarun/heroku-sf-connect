SfDbSync.setup do |config|
  # config.app_root = app.root
  
  #Load the configuration from the environment or a yaml file or disable it if no config present
  SfDbSync.config = Hash.new
  #load the config file if we have it
  if FileTest.exist?("#{Rails.root}/config/sf_db_sync.yml")
    config = YAML.load_file("#{Rails.root}/config/sf_db_sync.yml")[Rails.env]
    SfDbSync.config["ORGANIZATION_ID"] = config['organization_id']
    SfDbSync.config["SYNC_ENABLED"] = config['sync_enabled']
    SfDbSync.config["IP_RANGES"] = config['ip_ranges'].split(',').map{ |ip| ip.strip }
    SfDbSync.config["NAMESPACE_PREFIX"] = config['namespace_prefix']
  end

  #if we have ENV flags prefer them
  SfDbSync.config["ORGANIZATION_ID"] = ENV["SALESFORCE_AR_SYNC_ORGANIZATION_ID"] if ENV["SALESFORCE_AR_SYNC_ORGANIZATION_ID"]
  SfDbSync.config["SYNC_ENABLED"] = ENV["SALESFORCE_AR_SYNC_SYNC_ENABLED"] if ENV.include? "SALESFORCE_AR_SYNC_SYNC_ENABLED"
  SfDbSync.config["IP_RANGES"] = ENV["SALESFORCE_AR_SYNC_IP_RANGES"].split(',').map{ |ip| ip.strip } if ENV["SALESFORCE_AR_SYNC_IP_RANGES"]
  SfDbSync.config["NAMESPACE_PREFIX"] = ENV["SALESFORCE_AR_NAMESPACE_PREFIX"] if ENV["SALESFORCE_AR_NAMESPACE_PREFIX"]

  #do we have valid config options now?
  if !SfDbSync.config["ORGANIZATION_ID"].present? || SfDbSync.config["ORGANIZATION_ID"].length != 18
    SfDbSync.config["SYNC_ENABLED"] = false
  end
end

