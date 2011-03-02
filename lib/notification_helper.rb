require 'httparty'

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

  def push_and_get_response raw_response
    result = {
        :response => parse_response(raw_response.parsed_response), # the string ex:- Error=NotRegistered
        :http_status_code => raw_response.response
    }

    C2dmLogger.log.debug "push_and_get_response [#{result}]"
    result
  end

  ERROR_STRING = "Error="
  def parse_response response
    {
        :is_error => response.include?(ERROR_STRING), # does this response indicate a error?
        :description => response.gsub(ERROR_STRING, "")
    }
  end

  def manage_counts counts, response
    if response[:response][:is_error]
      counts[:error_count] = counts[:error_count] + 1
    else
      counts[:success_count] = counts[:success_count] + 1
    end
    C2dmLogger.log.debug "Counts updated [#{counts}]"
  end
end