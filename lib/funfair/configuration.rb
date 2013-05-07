module Funfair
  class Configuration
    attr_accessor :logger
    attr_accessor :namespace
    attr_accessor :connection_options_or_string

    def initialize
      self.logger = Logger.new(STDOUT)
      self.log_level = Logger::INFO
      self.connection_options_or_string = {}
    end

    def log_level=(level)
      self.logger.level = level
    end

    def subscribers=(subscribers)
      @subscribers = subscribers
    end

    def subscribers
      @subscribers
    end

    def declare(pubsub)
      self.subscribers.each do |subscriber|
        subscriber.subscriptions.each do |subscription|
          subscription.declare(pubsub)
        end
      end
    end
  end
end
