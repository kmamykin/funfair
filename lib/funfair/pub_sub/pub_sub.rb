module Funfair
  module PubSub
    class PubSub

      def initialize(client)
        @client = client
      end

      def subscribe(event_name, handler_id, &block)
        subscribers.subscribe(event_name, handler_id, &block)
      end

      def publish(event_name, event_data=nil)
        #TODO: shell we enforce that event_name has subscribers? i.e. event data will end up somewhere?
        subscribers.on_declared do
          publisher.publish(event_name, event_data)
        end
      end

      def start
        subscribers.start
      end

      def on_consuming(&block)
        subscribers.on_consuming(&block)
      end

      def delete_all(&block)
        subscribers.delete_all(&block)
      end

      protected

      def publisher
        @publisher ||= ConfirmedPublisher.new(@client)
      end

      def subscribers
        @subscribers ||= Subscribers.new(@client)
      end
    end
  end
end