module Funfair
  module PubSub
    class Subscription
      attr_reader :exchange_name, :queue_name, :handler
      attr_reader :logger

      def initialize(exchange_name, queue_name, handler)
        @exchange_name, @queue_name, @handler = exchange_name.to_s, queue_name.to_s, handler
        @on_declared = EventMachine::Completion.new
        @on_consuming = EventMachine::Completion.new
        @consuming = false
        @declared = false
        @logger = Funfair.logger
      end

      def on_declared(&block)
        @on_declared.callback(&block)
      end

      def on_consuming(&block)
        @on_consuming.callback(&block)
      end

      def declare(channel)
        EM.next_tick do
          channel.fanout(exchange_name, :durable => true) do |exchange, declare_ok|
            channel.queue(queue_name, :durable => true) do |queue, declare_ok| # durable queue
              logger.debug "Subscribing to #{exchange_name} with handler #{queue_name} on channel #{channel.id}"
              queue.bind(exchange) do |bind_ok|
                logger.debug "Bound to exchange #{exchange.name}"
                @declared = true
                @on_declared.succeed exchange, queue
              end
            end
          end
        end
      end

      def declared?
        @declared
      end

      def subscribe
        @on_declared.callback do |exchange, queue|
          EM.next_tick do
            # :ack is for message acknowledgement, once confirmed -> call block
            on_confirm = proc do
              @consuming = true
              @on_consuming.succeed
            end
            queue.subscribe({:ack => true, :confirm => on_confirm}, &method(:handle_message))
          end
        end
      end

      def consuming?
        @consuming
      end

      def delete(&block)
        @on_declared.callback do |exchange, queue|
          EM.next_tick do
            exchange.delete
            logger.debug "Deleting queue #{queue.name}..."
            queue.delete do |delete_ok|
              logger.debug "Deleted queue #{queue.name} with #{delete_ok.message_count} messages"
              @deleted = true
              block.call
            end
          end
        end
      end

      def deleted?
        @deleted
      end

      private

      def handle_message(metadata, data)
        EventMachine.defer do
          begin
            logger.debug "Subscriber: got metadata: #{metadata}, data: #{data}"
            deserialized = MultiJson.load(data)
            handler.call deserialized
            EventMachine.next_tick { metadata.ack }
          rescue Exception => ex
            logger.error ex.inspect
            # reject and requeue
            EventMachine.next_tick { metadata.reject(:requeue => false) }
          end
        end
      end
    end
  end
end