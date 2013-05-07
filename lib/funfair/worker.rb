module Funfair
  class Worker
    # used to run as a standalone application
    def initialize
      Funfair.configure do |config|
        config.logger = Logger.new(STDOUT)
        config.log_level = Logger::DEBUG
      end
    end

    # Starts
    def self.start
      self.new.start
    end

    def start
      Signal.trap "TERM", &method(:shutdown)
      Signal.trap "INT", &method(:shutdown)
      EM.run do
        @client = Funfair.connect
        @client.pubsub.start
        @client.pubsub.on_consuming { puts "Started subscribers." }
      end
    end

    def shutdown(*args) # without *args System.trap will throw an exception
      puts "Disconnected. Exiting..."
      @client.disconnect { EM.stop }
    end
  end

end