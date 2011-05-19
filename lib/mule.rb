require "typhoeus"
require "mule_notification_helper"

module C2DM
  AUTH_URL = 'https://www.google.com/accounts/ClientLogin'
  PUSH_URL = 'https://android.apis.google.com/c2dm/send'
  ERROR_STRING = "Error="
  C2DM_QUOTA_EXCEEDED_ERROR_MESSAGE_DESCRIPTION = "QuotaExceeded"

  class Mule
    include MuleNotificationHelper

    attr_accessor :stats, :notifications_to_retry, :request_to_notification_map

    def initialize(username, password, source)
      self.stats={
          :responses => [],
          :unknown_errors => [],
          :timeouts => [],
          :quota_exceeded => [],
          :counts => {
              :successes => 0,
              :retries => {
                  :quota_exceeded => 0,
                  :timeouts => 0
              }
          }
      }

      self.notifications_to_retry={
          :quota_exceeded => [],
          :timeouts => []
      }

      self.request_to_notification_map={}

      get_auth_token username, password, source
    end

    def get_auth_token username, password, source
      post_body = "accountType=HOSTED_OR_GOOGLE&Email=#{username}&Passwd=#{password}&service=ac2dm&source=#{source}"

      @auth_token=C2DM::Push.extract_authentication_token(
          Typhoeus::Request.post(C2DM::AUTH_URL,
                                 :body => post_body,
                                 :headers => {
                                     'Content-type' => 'application/x-www-form-urlencoded',
                                     'Content-length' => "#{post_body.length}"
                                 }
          )
      )
    end

    def schieben notifications
      ready_and_queue_requests notifications, hydra=i_can_haz_hydra
      hydra.run

      retry_notifications :quota_exceeded
      retry_notifications :timeouts

      stats[:counts][:successes] = stats[:responses].count { |r| !r[:is_error] }
      stats[:counts][:failures] = notifications.count - stats[:counts][:successes]
      stats[:counts][:total] = notifications.count
      puts "done"
      puts stats
      puts request_to_notification_map
      stats
    end

    def retry_notifications collection, max_retries=3
      retries = 0
      while retries < max_retries && notifications_to_retry[collection].count > 0
        retries += 1
        puts retries
        ready_and_queue_requests(notifications_to_retry[collection], hydra=i_can_haz_hydra)
        notifications_to_retry[collection].clear
        stats[collection].clear
        hydra.run
      end

      stats[:counts][:retries][collection] += retries #remmber the total number of retries per collection (timeouts...etc)
    end

    def ready_and_queue_requests notifications, hydra
      notifications.each do |n|
        (
          request = Typhoeus::Request.new(
              PUSH_URL,
              :method => :post,
              :timeout => 100, # milliseconds
              :body => "registration_id=#{n[:registration_id]}&collapse_key=foobar&#{self.get_data_string(n[:key_value_pairs])}",
              :headers => {
                  'Authorization' => "GoogleLogin auth=#{@auth_token}"
              }
          )
        ).on_complete do |r|
          if r.success?
            # Quota Exceeded or not?
            if is_error=r.body.include?(ERROR_STRING)
              quota_exceeded=(r.body.gsub(ERROR_STRING, "") == QuotaExceededException)
            end

            if quota_exceeded
              notifications_to_retry[:quota_exceeded] << request_to_notification_map[r]
              build_status :quota_exceeded, r, true, r.code, false, QuotaExceededException
            else
              build_status(:responses, r, is_error, r.code, false, if(is_error)
                                                                    r.body.gsub(ERROR_STRING, "")
                                                                  else
                                                                    r.body
                                                                  end
              )
            end
          elsif r.timed_out?
            notifications_to_retry[:timeouts] << request_to_notification_map[r]
            build_status :timeouts, r, true, r.code, true, r.curl_error_message
            # aw hell no
            log("got a time out")
          elsif r.code == 0
            build_status :unknown_errors, r, true, r.code, false, r.curl_error_message
            # Could not get an http response, something's wrong.
            log(r.curl_error_message)
          else
            build_status :responses, r, true, r.code, false, r.body.gsub(ERROR_STRING, "")
            # Received a non-successful http response.
            log("HTTP request failed: " + r.code.to_s)
          end
        end

        request_to_notification_map[request] = n
        hydra.queue request
      end
    end

  end
end