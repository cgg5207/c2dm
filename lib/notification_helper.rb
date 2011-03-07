require 'httparty'
require "c2dm_logger.rb"
require "ap"

module NotificationHelper
  include HTTParty
  default_timeout 30

  # Construct the html parameter, value string from the give map object
  def get_data_string(map)
    data = ''
    map.keys.each do |k|
      data = "#{data}&data.#{k.to_s}=#{CGI::escape(map[k].to_s)}"
    end

    data
  end

  def parse_push_response httparty_response
    result = {
        :response => parse_response(httparty_response), # the string ex:- Error=NotRegistered
        :http_status_code => httparty_response.response
    }

    C2DM::C2dmLogger.log.debug "parse_response [#{result}]"
    result
  end

  ERROR_STRING = "Error="
  def parse_response httparty_response
    {
        :is_error => is_error=is_error?(httparty_response),
        :description => if is_error
                          httparty_response.parsed_response.gsub(ERROR_STRING, "")
                        else
                          httparty_response.parsed_response
                        end
    }
  end

  # Check and identify a whether this response contains a error
  # make sure the status is 200 and the string does not contain the defined error string
  def is_error? raw_response
    raw_response.response.class != Net::HTTPOK || raw_response.parsed_response.include?(ERROR_STRING)
  end
end