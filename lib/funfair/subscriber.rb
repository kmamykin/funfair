module Funfair
  class Subscriber
    attr_reader :event_name, :handler_id, :handler

    def initialize(event_name, handler_id, handler)
      @event_name, @handler_id, @handler = event_name, handler_id, handler
    end

    def bind(channel, &block)
      EM.next_tick do
        channel.fanout(event_name.to_s, :durable => true) do |exchange, declare_ok|
          @exchange = exchange
          channel.queue(handler_id.to_s, :durable => true) do |queue, declare_ok| # durable queue
            puts "Subscribing to #{event_name} with handler #{handler_id} on channel #{channel.id}"
            queue.bind(exchange) do |bind_ok|
              puts "Bound to exchange #{exchange.name}"
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

    def delete(&block)
      EM.next_tick do
        #@exchange.delete
        puts "Deleting queue #{@queue.name}..."
        @queue.delete do |delete_ok|
          puts "Deleted queue #{@queue.name} with #{delete_ok.message_count} messages"
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
      handler.call data
      metadata.ack
    rescue ex
      # reject and requeue
      metadata.reject(:requeue => true)
    end
  end

end