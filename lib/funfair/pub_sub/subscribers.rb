module Funfair
  module PubSub
    class Subscribers
      def initialize(session)
        @subscriptions = []
        @channel_completion = EventMachine::Completion.new
        @all_declared = EventMachine::Completion.new
        @all_consuming = EventMachine::Completion.new
        session.connected { |connection| obtain_subscribing_channel(connection) }
      end

      # define subscription, but do not start consuming
      def subscribe(exchange_name, queue_name, &handler)
        Subscription.new(exchange_name, queue_name, handler).tap do |subscription|
          @subscriptions << subscription
          # attach callbacks to track completion of all subscriptions
          subscription.on_declared { |exchange, queue| check_all_declared }
          subscription.on_consuming { check_all_consuming }
          # Start consuming when channel is ready
          @channel_completion.callback { |channel| subscription.declare(channel) }
        end
      end

      def start
        on_declared do
          @subscriptions.each { |s| s.subscribe }
        end
      end

      # Call block when all exchanges & queues have been declared and bound
      def on_declared(&block)
        @all_declared.callback(&block)
      end

      # Call block when all subscriptions are subscribed and consuming messages
      def on_consuming(&block)
        @all_consuming.callback(&block)
      end

      def delete_all(&block)
        if @subscriptions.empty?
          block.call
        else
          @subscriptions.each do |s|
            s.delete do
              block.call if all_deleted?
            end
          end
        end
      end

      private

      def obtain_subscribing_channel(connection)
        EventMachine.next_tick do
          ::AMQP::Channel.new(connection) do |channel, open_ok|
            channel.on_error(&method(:on_channel_error))
            channel.auto_recovery = true # Rely on auto-recovery to re-declare all exchanges/queues/bindings
            channel.prefetch(1) do # For message ack need to prefetch one message
              @channel_completion.succeed(channel)
            end
          end
        end
      end

      def check_all_declared
        @all_declared.succeed if all_declared?
      end

      def check_all_consuming
        @all_consuming.succeed if all_consuming?
      end

      def all_declared?
        @subscriptions.empty? || @subscriptions.all?(&:declared?)
      end

      def all_consuming?
        @subscriptions.empty? || @subscriptions.all?(&:consuming?)
      end

      def all_deleted?
        @subscriptions.empty? || @subscriptions.all?(&:deleted?)
      end

      def on_channel_error(channel, channel_close)
        fail "Channel-level exception on subscribing channel: #{channel_close.reply_text}"
      end
    end
  end
end