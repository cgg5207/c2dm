require "c2dm_logger.rb"

# This module contains a number of helper methods used for sending c2dm notifications
module MuleNotificationHelper

  # Construct the html parameter, value string from the given map object
  def get_data_string(map)
    data = ''
    map.keys.each do |k|
      data = "#{data}&data.#{k.to_s}=#{CGI::escape(map[k].to_s)}"
    end
    data
  end

  # build our own response from the httparty response object
  def parse_push_response httparty_response
    result = {
        :response => parse_response(httparty_response), # parse_response gives => ex:- Error=NotRegistered
        :http_status_code => httparty_response.response.code # ie: 200 if sucessful
    }

    C2DM::C2dmLogger.log.debug "parse_response [#{result}]"
    result
  end

  ERROR_STRING = "Error="

  # Detect a error and extract it if present. If not just get the returned response string
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

  # Check and identify whether this response contains a error
  # make sure the status is 200 and the string does not contain the defined error string
  def is_error? httparty_response
    httparty_response.response.class != Net::HTTPOK || httparty_response.parsed_response.include?(ERROR_STRING)
  end
end