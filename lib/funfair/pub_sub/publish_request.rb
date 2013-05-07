module Funfair
  module PubSub
    # Represents an asynchronous request to publish event to an exchange.
    # Usage:
    # request = publisher.publish(exchange_name, message_data)
    # request.callback { puts "Succeeded" }
    # request.errback { |error_message| puts error_message }
    # See: http://eventmachine.rubyforge.org/docs/DEFERRABLES.html
    class PublishRequest
      include EventMachine::Deferrable

      attr_accessor :tag
      attr_reader :logger

      def initialize(publisher, exchange_name, message_data)
        @publisher, @exchange_name, @message_data = publisher, exchange_name.to_s, message_data
        @timeout = 30 # in sec
        @logger = Funfair.logger
      end

      def publish
        @publisher.on_channel_ready do |channel|
          EM.next_tick do
            logger.debug "Declaring publisher's exchange: #{@exchange_name}"
            channel.fanout(@exchange_name, :durable => true) do |exchange|
              # publisher_index should have been incremented by exchange.publish in channel after_publish callback
              self.tag = channel.publisher_index + 1
              logger.debug "Publishing message: #{@message_data} to #{exchange.name}"
              exchange.publish(@message_data, {:persistent => true}) do
                logger.debug "Message sent: #{@message_data}"
                # this is executed on EM.next_tick
                # and just means that AMQP passed the message to OS, no other guarantees made at this point

                timeout @timeout, 'PublishRequest timed out without confirmation (either ACK or NACK).'
              end
            end
          end
        end
      end

      def ack!(tag, multiple)
        succeed if matches_tag?(tag, multiple)
      end

      def nack!(tag, multiple, reason)
        fail(reason) if matches_tag?(tag, multiple)
      end

      def fail!(reason)
        fail reason
      end

      def matches_tag?(tag, multiple)
        return false unless tag
        multiple ? self.tag <= tag : self.tag == tag
      end
    end
  end
end