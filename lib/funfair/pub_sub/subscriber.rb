module Funfair
  module PubSub
    class Subscriber
      attr_reader :exchange_name, :queue_name, :handler
      attr_reader :logger

      def initialize(exchange_name, queue_name, handler)
        @exchange_name, @queue_name, @handler = exchange_name.to_s, queue_name.to_s, handler
        @logger = Funfair.logger
      end

      def bind(channel, &block)
        EM.next_tick do
          channel.fanout(exchange_name, :durable => true) do |exchange, declare_ok|
            @exchange = exchange
            channel.queue(queue_name, :durable => true) do |queue, declare_ok| # durable queue
              logger.debug "Subscribing to #{exchange_name} with handler #{queue_name} on channel #{channel.id}"
              queue.bind(exchange) do |bind_ok|
                logger.debug "Bound to exchange #{exchange.name}"
                @queue = queue
                block.call
              end
            end
          end
        end
      end

      def bound?
        !!@queue
      end

      def subscribe(&block)
        EM.next_tick do
          # :ack is for message acknowledgement, once confirmed -> call block
          @queue.subscribe({:ack => true, :confirm => proc { @subscribed = true; block.call }}, &method(:handle_message))
        end
      end

      def subscribed?
        @subscribed
      end

      def subscribed_to?(exchange_name, queue_name)
        self.exchange_name == exchange_name.to_s && self.queue_name == queue_name
      end

      def delete(&block)
        EM.next_tick do
          #@exchange.delete
          logger.debug "Deleting queue #{@queue.name}..."
          @queue.delete do |delete_ok|
            logger.debug "Deleted queue #{@queue.name} with #{delete_ok.message_count} messages"
            @queue = nil
            block.call
          end
        end
      end

      def deleted?
        @queue.nil?
      end

      private

      def handle_message(metadata, data)
        logger.debug "Subscriber: got metadata: #{metadata}, data: #{data}"
        handler.call data
        metadata.ack
      rescue Exception => ex
        # reject and requeue
        metadata.reject(:requeue => true)
      end
    end
  end
end