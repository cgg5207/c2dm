module C2DM
  class C2dmLogger
    require 'logger'

    APP_NAME = "c2dm_lib"
    LOGGER_INSTANCE = Logger.new(STDOUT)
    LOGGER_INSTANCE.level = Logger::DEBUG
    C2DM_LOGGER_INSTANCE = C2dmLogger.new

    def self.log
      C2DM_LOGGER_INSTANCE
    end

    def method_missing(m, *args, &block)
	    LOGGER_INSTANCE.send(m, APP_NAME) {args[0]}
	  end
  end
end