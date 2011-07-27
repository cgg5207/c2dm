require "c2dm_logger.rb"
require "typhoeus"

# This module contains a number of helper methods used for sending c2dm notifications
module MuleNotificationHelper

  def log
    C2DM::C2dmLogger.log
  end

  def i_can_haz_hydra
    hydra=Typhoeus::Hydra.new(:max_concurrency => 2)
    hydra.disable_memoization
    hydra
  end

  def build_status collection, response, is_error, is_timeout, description
    stats[collection] << {
                  :registration_id => request_to_notification_map[response.request][:registration_id],
                  :key_value_pairs => request_to_notification_map[response.request][:key_value_pairs],
                  :is_error => is_error,
                  :http_status_code => response.code,
                  :is_timeout? => is_timeout,
                  :description => description
              }

    stats[:time][:total] += response.time
    stats[:time][:no_of_responses] += 1
  end

  # Construct the html parameter, value string from the given map object
  def get_data_string(map)
    data = ''
    map.keys.each do |k|
      data = "#{data}&data.#{k.to_s}=#{CGI::escape(map[k].to_s)}"
    end
    data
  end

end