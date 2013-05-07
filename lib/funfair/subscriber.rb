module Funfair
  module Subscriber
    def self.included(base)
      base.extend DSL
    end

    module DSL
      # define subscriptions
      def on(*event_names, &handler)
        event_names.each do |event_name|
          subscriptions << ClassSubscription.new(self, event_name, &handler)
        end
      end

      # each subscriber has multiple subscriptions
      def subscriptions
        @subscriptions ||= []
      end
    end

    class ClassSubscription

      def initialize(klass, event_name, &handler)
        @klass, @event_name, @handler = klass, event_name, handler
      end

      def declare(pubsub)
        pubsub.subscribe(exchange_name, queue_name, &handler)
      end

      private

      def exchange_name
        @event_name.to_s
      end

      def queue_name
        handler_id.to_s
      end

      def handler
        @handler
      end

      def handler_id
        check_namespace!

        [namespace, @klass.name, @event_name].compact.join('.')
      end

      def check_namespace!
        unless namespace
          Funfair.logger.warn "To avoid naming collisions between handlers in different applications, it's strongly advised to set 'Funfair.namespace' to a unique identifier of your application"
        end
      end

      def namespace
        Funfair.configuration.namespace
      end
    end
  end
end