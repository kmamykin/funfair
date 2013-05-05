module Funfair
  class Configuration
    attr_accessor :logger

    def initialize
      self.logger = Logger.new(STDOUT)
      self.log_level = Logger::INFO
    end

    def log_level=(level)
      self.logger.level = level
    end

  end
end
