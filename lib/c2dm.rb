require 'httparty'
require 'cgi'

module C2DM
  class Push
    include HTTParty
    default_timeout 30

    attr_accessor :timeout

    AUTH_URL = 'https://www.google.com/accounts/ClientLogin'
    PUSH_URL = 'https://android.apis.google.com/c2dm/send'

    def initialize(username, password, source)
      post_body = "accountType=HOSTED_OR_GOOGLE&Email=#{username}&Passwd=#{password}&service=ac2dm&source=#{source}"
      params = {:body => post_body,
                :headers => {'Content-type' => 'application/x-www-form-urlencoded', 
                             'Content-length' => "#{post_body.length}"}}

      response = Push.post(AUTH_URL, params)
      response_split = response.body.split("\n")
      @auth_token = response_split[2].gsub("Auth=", "")
    end

    def send_notification(registration_id, message)
      post_body = "registration_id=#{registration_id}&collapse_key=foobar&data.message=#{CGI::escape(message)}"
      params = {:body => post_body,
                :headers => {'Authorization' => "GoogleLogin auth=#{@auth_token}"}}

      response = Push.post(PUSH_URL, params)
      response
    end

    # Construct the html parameter, value string from the give map object
    def self.get_data_string(map)
      data = ''
      key_value_pairs.keys.each do |k|
        data = "#{data}&data.#{k.to_s}=#{CGI::escape(map[k].to_s)}"
      end
      
      data
    end

    # Send a C2DM notification with a set of other parameters and values, as given in the map
    def send_notification_with_kv_map(registration_id, map)
      post_body = "registration_id=#{registration_id}&collapse_key=foobar&#{Push.get_data_string(map)}"
      params = {:body => post_body,
                :headers => {'Authorization' => "GoogleLogin auth=#{@auth_token}"}}

      response = Push.post(PUSH_URL, params)
      response
    end

    # Send C2DM notifications with a set of other parameters and values, as given in the map.
    # The notifications array should consists of map objects like:
    # {:registration_id => "x", :key_value_pairs => { :key_one => "value_one", :key_two => "value_two" }}
    # The passed in key value pairs will be sent through C2DM
    def self.send_notifications_with_kv_map(username, password, source, notifications)
      c2dm = Push.new(username, password, source)
    
      responses = []
      notifications.each do |notification|
        responses << {:body => c2dm.send_notification_with_kv_map(notification[:registration_id], notification[:key_value_pairs]), :registration_id => notification[:registration_id]}
      end
      responses
    end

    def self.send_notifications(username, password, source, notifications)
      c2dm = Push.new(username, password, source)
    
      responses = []
      notifications.each do |notification|
        responses << {:body => c2dm.send_notification(notification[:registration_id], notification[:message]), :registration_id => notification[:registration_id]}
      end
      responses
    end

  end
end