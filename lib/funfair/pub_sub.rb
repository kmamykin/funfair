module Funfair
  class PubSub

    def initialize(client)
      @client = client
      @client.connect
    end

    def publish(event_name, event_data = nil)
      publisher.publish(event_name, event_data = nil)
    end

    def subscribe(event_name, handler_id, &block)
      subscribers.subscribe(event_name, handler_id, &block)
    end

    def on_ready(&block)
      subscribers.all_listening(&block)
    end

    def delete_all(&block)
      subscribers.delete_all(&block)
    end

    protected

    def publisher
      @publisher ||= PubSubPublisher.new(@client)
    end

    def subscribers
      @subscribers ||= Subscribers.new(@client)
    end
  end
end