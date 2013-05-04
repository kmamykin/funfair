module Funfair
  class Client

    def initialize(options)
      @options = options
      @connected = EventMachine::Completion.new
    end

    # connection.connected {|connection| puts "Connected" }
    def connected(&block)
      @connected.callback(&block)
    end

    # connection.failed {|error| puts error }
    def failed(&block)
      @connected.errback(&block)
    end

    def connect
      unless @started_connection
        @started_connection = true
        ::AMQP::Utilities::EventLoopHelper.run do
          puts "CONNECTING TO AMQP SERVER ..."
          ::AMQP.connection = ::AMQP.connect(@options.merge({
              :on_tcp_connection_failure => method(:on_tcp_connection_failure),
              :on_possible_authentication_failure => method(:on_possible_authentication_failure)
          })) do |connection|
            connection.on_error(&method(:on_connection_error))
            connection.on_tcp_connection_loss(&method(:on_tcp_connection_loss))
            connection.on_connection_interruption(&method(:on_connection_interruption))
            log_connection_success(connection)
            @connected.succeed(connection)
          end
        end
      end
    end

    def disconnect(&block)
      puts "Scheduling disconnect..."
      EM.next_tick do
        puts "Disconnecting"
        ::AMQP.stop do
          block.call
        end
      end
    end

    def connection
      ::AMQP.connection
    end

    def connected?
      !!connection
    end

    def pubsub
      @pubsub ||= PubSub.new(self)
    end

    def close_channel(channel)
      if channel and channel.open? and channel.connection.open?
        channel.close
      end
    end

    def on_tcp_connection_failure
      puts "Can not establish connection. TCP connection failure."
      @connected.fail(:tcp_failure, "Can not establish connection. TCP connection failure.")
    end

    def on_possible_authentication_failure
      puts "Can not establish connection. Possible authentication failure."
      @connected.fail(:auth_failure, "Can not establish connection. Possible authentication failure.")
    end

    def on_connection_error(connection, connection_close)
      # Connection-level exceptions are rare and may indicate a serious issue with a client library or in-flight data corruption.
      # The AMQP 0.9.1 specification mandates that a connection that has errored cannot be used any more
      # and must be closed. In any case, your application should be prepared to handle this kind of error.
      # To define a handler, use AMQP::Session#on_error method that takes a callback and yields two arguments to it
      # when a connection-level exception happens:
      puts "Handling a connection-level exception."
      puts
      puts "AMQP class id : #{connection_close.class_id}"
      puts "AMQP method id: #{connection_close.method_id}"
      puts "Status code   : #{connection_close.reply_code}"
      puts "Error message : #{connection_close.reply_text}"
      # Handling graceful shutdown
      puts "[connection.close] Reply code = #{connection_close.reply_code}, reply text = #{connection_close.reply_text}"
      if connection_close.reply_code == 320
        puts "[connection.close] Setting up a periodic reconnection timer..."
        # every 30 seconds
        connection.periodically_reconnect(30)
      end

      raise connection_close.reply_text
    end

    def on_channel_error(channel, channel_close)
      puts "Channel-level exception on subscribing channel: #{channel_close.reply_text}"
      # handle it or throw
    end

    def on_tcp_connection_loss(connection, settings)
      # a callback that will be executed once when TCP connection fails.
      # It is possible that reconnection attempts will not succeed immediately,
      # so there will be subsequent failures. To react to those see
      # #on_connection_interruption
      # reconnect in 2 seconds, without enforcement
      connection.reconnect(false, 2)
    end

    def on_connection_interruption(connection)
      # Note that AMQP::Session#on_connection_interruption callback is called
      # before this event is propagated to channels, queues and so on.
      # Different applications handle connection failures differently.
      # It is very common to use AMQP::Session#reconnect method to schedule a reconnection to the same host,
      # or use AMQP::Session#reconnect_to to connect to a different one.
      # For some applications it is OK to simply exit and wait to be restarted at a later point in time,
      # for example, by a process monitoring system like Nagios or Monit.
      puts "Connection detected connection interruption"
      connection.reconnect(false, 2)
    end

    def log_connection_success(connection)
      puts "Connected to #{connection.hostname}:#{connection.port}/#{connection.vhost}"
      puts "Client properties:"
      puts connection.client_properties.inspect
      puts "Server properties:"
      puts connection.server_properties.inspect
      puts "Server capabilities:"
      puts connection.server_capabilities.inspect
      puts "Broker product: #{connection.broker.product}, version: #{connection.broker.version}"
      puts "Connected to RabbitMQ? #{connection.broker.rabbitmq?}"
      puts "Broker supports publisher confirms? #{connection.broker.supports_publisher_confirmations?}"
      puts "Broker supports basic.nack? #{connection.broker.supports_basic_nack?}"
      puts "Broker supports consumer cancel notifications? #{connection.broker.supports_consumer_cancel_notifications?}"
      puts "Broker supports exchange-to-exchange bindings? #{connection.broker.supports_exchange_to_exchange_bindings?}"
    end

  end

end