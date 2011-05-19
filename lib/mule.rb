require "typhoeus"
require "mule_notification_helper"
require "c2dm_logger.rb"

module C2DM
  AUTH_URL = 'https://www.google.com/accounts/ClientLogin'
  PUSH_URL = 'https://android.apis.google.com/c2dm/send'
  ERROR_STRING = "Error="
  C2DM_QUOTA_EXCEEDED_ERROR_MESSAGE_DESCRIPTION = "QuotaExceeded"

  class Mule
    include MuleNotificationHelper

    attr_accessor :stats, :notifications_to_retry, :request_to_notification_map

    def initialize(username, password, source)
      log.debug "Starting new Mule Instance"

      self.stats={
          :responses => [],
          :unknown_errors => [],
          :timeouts => [],
          :quota_exceeded => [],
          :time => {
              :total => 0.0,
              :no_of_responses => 0
          },
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

      log.info "Got auth token: #{@auth_token}"
    end

    def schieben notifications
      log.info "Start sending #{notifications.count} notifications"

      ready_and_queue_requests notifications, hydra=i_can_haz_hydra
      hydra.run

      retry_notifications :quota_exceeded
      retry_notifications :timeouts

      stats[:counts][:successes] = stats[:responses].count { |r| !r[:is_error] }
      stats[:counts][:failures] = notifications.count - stats[:counts][:successes]
      stats[:counts][:total] = notifications.count
      stats[:counts][:unknown_errors_count] = stats[:unknown_errors].count
      stats[:time][:average] = stats[:time][:total]/stats[:time][:no_of_responses]

      log.info "Notification Sending done. Stats will follow..."
      log.info stats.inspect
      stats
    end

    def retry_notifications collection, max_retries=3
      log.info "retry_notifications #{collection.to_s}"
      log.info notifications_to_retry[collection].inspect
      retries = 0
      while retries < max_retries && notifications_to_retry[collection].count > 0
        retries += 1
        log.info "Retry: #{retries}"
        ready_and_queue_requests(notifications_to_retry[collection], hydra=i_can_haz_hydra)
        notifications_to_retry[collection].clear
        stats[collection].clear
        hydra.run
      end

      stats[:counts][:retries][collection] += retries #remmber the total number of retries per collection (timeouts...etc)
    end

    def ready_and_queue_requests notifications_col, hydra
      log.info "ready_and_queue_requests"
      notifications_col.each do |notification|
        (
          request = Typhoeus::Request.new(
              PUSH_URL,
              :method => :post,
              #:timeout => 100, # milliseconds
              :body => "registration_id=#{notification[:registration_id]}&collapse_key=foobar&#{self.get_data_string(notification[:key_value_pairs])}",
              :headers => {
                  'Authorization' => "GoogleLogin auth=#{@auth_token}"
              }
          )
        ).on_complete do |response|
          if response.success?
            # Quota Exceeded or not?
            is_error=response.body.include?(ERROR_STRING)
            if (
                 is_error &&
                (
                  response.body.gsub(ERROR_STRING, "") == QuotaExceededException
                )
              )
              notifications_to_retry[:quota_exceeded] << request_to_notification_map[response.request]
              build_status :quota_exceeded, response, true, false, QuotaExceededException
              log.warn "Quota Exceeded. Notificaton: #{request_to_notification_map[response.request]}"
            else
              build_status(:responses, response, is_error, false, if(is_error)
                                                                    response.body.gsub(ERROR_STRING, "")
                                                                  else
                                                                    response.body
                                                                  end
              )
            end
          elsif response.timed_out?
            notifications_to_retry[:timeouts] << request_to_notification_map[response.request]
            build_status :timeouts, response, true, true, response.curl_error_message
            log.warn "Timeout. Curl Error: #{response.curl_error_message} Notificaton: #{request_to_notification_map[response.request]}"
          elsif response.code == 0
            build_status :unknown_errors, response, true, false, response.curl_error_message
            # Could not get an http response, something is wrong.
            #log(response.curl_error_message)
            log.warn "Could not get a http response. Curl Error: #{response.curl_error_message} Notificaton: #{request_to_notification_map[response.request]}"
          else
            build_status :responses, response, true, false, response.body.gsub(ERROR_STRING, "")
            # Received a non-successful http response.
            #log("HTTP request failed: " + response.code.to_s)
            log.warn "HTTP request failed: #{response.code.to_s} Request body: #{response.body} Notificaton: #{request_to_notification_map[response.request]}"
          end
        end

        request_to_notification_map[request] = notification
        hydra.queue request
      end
    end

  end
end