module Funfair
  class Worker
    # used to run as a standalone application
    def initialize(client)
      @client = client
    end

    # Starts
    def start
      Signal.trap "TERM", &method(:shutdown)
      Signal.trap "INT", &method(:shutdown)
      EM.run do
        @client.subscribers.all_listening { puts "Started and Ready" }
      end
    end

    def shutdown
      puts "Disconnected. Exiting..."
      @client.disconnect { EM.stop }
    end

  end

end