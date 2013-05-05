module Funfair
  class Subscribers
    def initialize(session)
      @subscribers = []
      @channel_completion = EventMachine::Completion.new
      session.connected { |connection| obtain_subscribing_channel(connection) }
    end

    # TODO: make it
    # subscription_request = session.subscribe(exchange_name, queue_name, &consumer)
    # subscription_request.callback{}
    # subscription_request.errback{}
    def subscribe(exchange_name, queue_name, &handler)
      @subscribers << Subscriber.new(exchange_name, queue_name, handler)
    end

    def subscribe?(exchange_name, queue_name)
      @subscribers.any? { |s| s.subscribed_to?(exchange_name, queue_name)}
    end

    def all_listening(&block)
      bind_all do
        subscribe_all(&block)
      end
    end

    def bind_all(&block)
      @channel_completion.callback do |channel|
        if @subscribers.empty?
          block.call
        else
          @subscribers.each do |s|
            s.bind(channel) do
              block.call if all_bound?
            end
          end
        end
      end
    end

    def subscribe_all(&block)
      if @subscribers.empty?
        block.call
      else
        @subscribers.each do |s|
          s.subscribe do
            block.call if all_subscribed?
          end
        end
      end
    end

    def delete_all(&block)
      if @subscribers.empty?
        block.call
      else
        @subscribers.each do |s|
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

    def all_bound?
      @subscribers.all?(&:bound?)
    end

    def all_subscribed?
      @subscribers.all?(&:subscribed?)
    end

    def all_deleted?
      @subscribers.all?(&:deleted?)
    end

    def on_channel_error(channel, channel_close)
      puts "Channel-level exception on subscribing channel: #{channel_close.reply_text}"
    end
  end

end