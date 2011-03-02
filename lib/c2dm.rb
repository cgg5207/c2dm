require 'httparty'
require 'cgi'
require "notification_helper.rb"
require "c2dm_logger.rb"

module C2DM
  class Push
    include HTTParty
    default_timeout 30

    include NotificationHelper

    attr_accessor :timeout

    AUTH_URL = 'https://www.google.com/accounts/ClientLogin'
    PUSH_URL = 'https://android.apis.google.com/c2dm/send'

    def initialize(username, password, source)
      C2dmLogger.log.debug "Start: initialize Push with [#{username}, #{password}, #{source}]"
      post_body = "accountType=HOSTED_OR_GOOGLE&Email=#{username}&Passwd=#{password}&service=ac2dm&source=#{source}"
      params = {:body => post_body,
                :headers => {'Content-type' => 'application/x-www-form-urlencoded', 
                             'Content-length' => "#{post_body.length}"}}

      response = Push.post(AUTH_URL, params)
      C2dmLogger.log.debug "Received response [#{response}]"
      response_split = response.body.split("\n")
      @auth_token = response_split[2].gsub("Auth=", "")
      C2dmLogger.log.debug "Received auth_token [#{@auth_token}]"
    end

    def send_notification(registration_id, message)
      C2dmLogger.log.debug "Start: send_notification with [#{registration_id}, #{message}]"
      post_body = "registration_id=#{registration_id}&collapse_key=foobar&data.message=#{CGI::escape(message)}"
      params = {:body => post_body,
                :headers => {'Authorization' => "GoogleLogin auth=#{@auth_token}"}}

      push_and_get_response Push.post(PUSH_URL, params)
    end

    # Send a C2DM notification with a set of other parameters and values, as given in the map
    def send_notification_with_kv_map(registration_id, map)
      C2dmLogger.log.debug "Start: send_notification_with_kv_map with [#{registration_id}, #{map}]"
      post_body = "registration_id=#{registration_id}&collapse_key=foobar&#{get_data_string(map)}"
      params = {:body => post_body,
                :headers => {'Authorization' => "GoogleLogin auth=#{@auth_token}"}}

      push_and_get_response Push.post(PUSH_URL, params)
    end

    # Send C2DM notifications with a set of other parameters and values, as given in the map.
    # The notifications array should consists of map objects like:
    # {:registration_id => "x", :key_value_pairs => { :key_one => "value_one", :key_two => "value_two" }}
    # The passed in key value pairs will be sent through C2DM
    def self.send_notifications_with_kv_map(username, password, source, notifications)
      C2dmLogger.log.debug "Start: send_notification_with_kv_map with [#{username}, #{password}, #{source}, #{notifications}]"
      responses = []
      exception = nil
      start_point = 0
      counts = {
          :success_count => 0,
          :error_count => 0,
          :exception_count => 0
      }

      while true do
        begin
          c2dm = Push.new(username, password, source)
          #notifications.each do |notification|
          C2dmLogger.log.debug "send_notification_with_kv_map start sending notifications [start_point:#{start_point}, total # of notifications:#{notifications.size}]"
          for i in start_point..notifications.size-1
            notification = notifications[i]
            C2dmLogger.log.debug "Sending notification [position:#{i}, notification:#{notification}]"
            responses << {:response => response=c2dm.send_notification_with_kv_map(notification[:registration_id], notification[:key_value_pairs]), :registration_id => notification[:registration_id]}
            C2dmLogger.log.debug "Sending notification result [position:#{i}, notification:#{notification}, result:#{response}]"
            manage_counts counts, response
          end

          C2dmLogger.log.debug "Reached the end of notification sending cycle."
          break # everything seems to have worked out fine. break!
        rescue Timeout::Error => timeout_ex
          counts[:timeout_count] = counts[:timeout_count] +1
          C2dmLogger.log.warn "Timeout::Error retrying [count:#{counts[:timeout_count]}, exception:#{timeout_ex}]"
          if counts[:timeout_count]=4 # max retries = 3, so break if this is the 4th time
            C2dmLogger.log.fatal "FATAL Timeout::Error, giving up [count:#{counts[:timeout_count]}, exception:#{timeout_ex}]"
            break
          end
        rescue Exception => ex
          exception = ex
          C2dmLogger.log.fatal "FATAL Unhandled Exception, giving up [exception:#{ex}]"
          break
        end
      end

      result = {
          :responses => responses,
          :counts =>  counts,
          :exception => exception
      }
      C2dmLogger.log.debug "send_notification_with_kv_map done. [#{result}]"
      result
    end

    # Send a batch of notifications
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