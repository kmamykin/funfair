module Funfair
  # Manages confirmed message sending to the broker
  # http://www.rabbitmq.com/confirms.html
  # http://rubyamqp.info/articles/broker_specific_extensions/#publisher_confirms_publisher_acknowledgements
  # Inspired by https://gist.github.com/eliaslevy/3042381
  class PubSubPublisher
    include EventMachine::Deferrable

    def initialize(session)
      # schedule channel initialization once connection is available
      session.connected do |connection|
        obtain_channel_with_confirmations(connection)
      end
    end

    def on_channel_ready(&block)
      self.callback(&block)
    end

    def publish(event_name, event_data = nil)
      PublishRequest.new(self, event_name, event_data).tap do |request|
        track(request)
        request.publish
      end
    end

    private

    def obtain_channel_with_confirmations(connection)
      EM.next_tick do
        ::AMQP::Channel.new(connection) do |channel, open_ok|
          # auto_recovery is always a good idea, this will re-declare exchanges when connection reconnects
          channel.auto_recovery = true
          # Publishing to this channel will need ack/nack confirmations from the brocker
          channel.on_error(&method(:handle_channel_error))
          channel.confirm_select do
            channel.on_ack(&method(:handle_ack))
            channel.on_nack(&method(:handle_nack))
            self.succeed(channel)
          end
        end
      end
    end

    def handle_ack(ack)
      puts "ACK: tag=#{ack.delivery_tag}, mul=#{ack.multiple}"
      ack_requests(ack.delivery_tag.to_i, ack.multiple)
    end

    def handle_nack(nack)
      puts "NACK: tag=#{nack.delivery_tag}, mul=#{nack.multiple}"
      nack_requests(nack.delivery_tag.to_i, nack.multiple, "NACK: tag=#{nack.delivery_tag}, mul=#{nack.multiple}")
    end

    def handle_channel_error(ch, channel_close)
      puts "Channel-level exception on publishing channel: #{channel_close.reply_text}"
      fail_requests("AMQP channel error #{channel_close.inspect}")
      fail("AMQP channel error #{channel_close.inspect}")
    end

    def ack_requests(tag, multiple)
      awaiting_confirmation.each { |request| request.ack!(tag, multiple) }
      check_all_confirmed
    end

    def nack_requests(tag, multiple, message)
      awaiting_confirmation.each { |request| request.nack!(tag, multiple, message) }
      check_all_confirmed
    end

    def fail_requests(message)
      awaiting_confirmation.each { |request| request.fail!(message) }
      check_all_confirmed
    end

    def check_all_confirmed
      if awaiting_confirmation.size == 0
        #EventMachine.next_tick do
        #  # possible call to indicate empty publishing queue
        #end
      end
    end

    def track(request)
      request.callback { awaiting_confirmation.delete(request) }
      request.errback { awaiting_confirmation.delete(request) }
      awaiting_confirmation.push(request)
    end

    # Keeps a list of unconfirmed requests
    # Most of the time the list will contain one or small number of requests
    def awaiting_confirmation
      @awaiting_confirmation ||= []
    end
  end
end