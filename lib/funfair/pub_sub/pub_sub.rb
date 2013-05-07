module Funfair
  module PubSub
    class PubSub

      attr_reader :logger

      def initialize(client)
        @client = client
        @logger = Funfair.logger
      end

      def publish(event_name, event_data=nil)
        #TODO: shell we enforce that event_name has subscribers? i.e. event data will end up somewhere?
        publisher.publish(event_name, event_data)
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
        @publisher ||= ConfirmedPublisher.new(@client)
      end

      def subscribers
        @subscribers ||= Subscribers.new(@client)
      end
    end
  end
end