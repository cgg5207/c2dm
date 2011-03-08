# Provide some logging to the c2dm lib using the inbuilt 'logger'
module C2DM
  # Main class hosting all the logic functionality. Host a single Logger instance and force every logging request
  # to go through it.
  class C2dmLogger
    require 'logger'
    require "ap"

    APP_NAME = "c2dm_lib"
    `mkdir -p log` # create a log directory if it does not exist
    LOGGER_INSTANCE = Logger.new("log/#{APP_NAME}.log", 10, 1024000) # log to a file, limit to 1MB/(rotate) 10 files
    #LOGGER_INSTANCE = Logger.new(STDOUT) # log to the std out
    LOGGER_INSTANCE.level = Logger::DEBUG
    C2DM_LOGGER_INSTANCE = C2dmLogger.new

    # get the logger instance
    def self.log
      C2DM_LOGGER_INSTANCE
    end

    # redirect all calls to methods, to the logger instance
    def method_missing(m, *args, &block)
	    LOGGER_INSTANCE.send(m, APP_NAME) {args[0]}
	  end
  end
end