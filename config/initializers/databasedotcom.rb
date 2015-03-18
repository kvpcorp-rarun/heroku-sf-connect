require "databasedotcom"

def perform_sync?
  ENV['PERFORM_SYNC'] != 'false'
end

if perform_sync?
  if File.exist?("#{::Rails.root.to_s}/config/databasedotcom.yml")
    sfdc_auth_config = YAML.load_file("#{::Rails.root.to_s}/config/databasedotcom.yml")[Rails.env]
    p sfdc_auth_config
    $sf_client = Databasedotcom::Client.new(sfdc_auth_config)
    sfdc_auth_config.stringify_keys!
    $sf_client.authenticate :username => sfdc_auth_config['username'], :password => sfdc_auth_config['password']
  else
    $sf_client = Databasedotcom::Client.new
    $sf_client.authenticate :username => ENV['DATABASEDOTCOM_USERNAME'], :password => ENV['DATABASEDOTCOM_PASSWORD']
  end

  module SfDbSync::SfDbSync
    SF_CLIENT = $sf_client
  end
end

