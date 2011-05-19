require "typhoeus"
require "mule_notification_helper"

module C2DM
  AUTH_URL = 'https://www.google.com/accounts/ClientLogin'
  PUSH_URL = 'https://android.apis.google.com/c2dm/send'
  ERROR_STRING = "Error="
  C2DM_QUOTA_EXCEEDED_ERROR_MESSAGE_DESCRIPTION = "QuotaExceeded"

  class Mule
    include MuleNotificationHelper

    attr_accessor :stats, :request_to_token_map

    def initialize(username, password, source)
      self.stats={
          :responses => [],
          :unknown_errors => [],
          :timeouts => [],
          :counts => {
              :successes => 0
          }
      }

      self.request_to_token_map={}

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
      hydra = Typhoeus::Hydra.new(:max_concurrency => 2)
      ready_and_queue_requests notifications, hydra
      hydra.run

      stats[:counts][:successes] = stats[:responses].count { |r| !r[:is_error] }
      stats[:counts][:failures] = notifications.count - stats[:counts][:successes]
      stats[:counts][:total] = notifications.count
      puts "done"
      puts stats
      puts request_to_token_map
      stats
    end

    def ready_and_queue_requests notifications, hydra
      notifications.each do |n|
        (
          request = Typhoeus::Request.new(
              PUSH_URL,
              :method => :post,
              :body => "registration_id=#{n[:registration_id]}&collapse_key=foobar&#{self.get_data_string(n[:key_value_pairs])}",
              :headers => {
                  'Authorization' => "GoogleLogin auth=#{@auth_token}"
              }
          )
        ).on_complete do |r|
          if r.success?
            stats[:responses] << {
                :registration_id => request_to_token_map[r.request],
                :key_value_pairs => "",
                :is_error => is_error=r.body.include?(ERROR_STRING),
                :http_status_code => r.code,
                :is_timeout? => false,
                :description => if is_error
                                  r.body.gsub(ERROR_STRING, "")
                                else
                                  r.body
                                end
            }
          elsif r.timed_out?
            stats[:timeouts] << {
                :registration_id => request_to_token_map[r.request],
                :key_value_pairs => "",
                :is_timeout? => true,
                :is_unknown_error => false,
                :http_status_code => "",
                :description => r.curl_error_message
            }

            # aw hell no
            log("got a time out")
          elsif r.code == 0
            stats[:unknown_errors] << {
                :registration_id => request_to_token_map[r.request],
                :key_value_pairs => "",
                :is_timeout? => false,
                :is_unknown_error => true,
                :http_status_code => "",
                :description => r.curl_error_message
            }

            # Could not get an http response, something's wrong.
            log(r.curl_error_message)
          else
            stats[:responses] << {
                :registration_id => request_to_token_map[r.request],
                :key_value_pairs => "",
                :is_timeout? => false,
                :is_unknown_error => false,
                :is_error => true,
                :http_status_code => r.code,
                :description => r.body
            }

            # Received a non-successful http response.
            log("HTTP request failed: " + r.code.to_s)
          end
        end

        request_to_token_map[request] = n[:registration_id]
        hydra.queue request
      end
    end

  end
end