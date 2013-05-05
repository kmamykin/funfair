module Funfair
  class Client

    attr_reader :logger

    def initialize(options)
      @options = options
      @logger = Funfair.logger
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
          logger.info "CONNECTING TO AMQP SERVER ..."
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
      EM.next_tick do
        logger.info "Disconnecting"
        ::AMQP.stop do
          logger.info "AMQP stopped"
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

    def reconnection_period
      5 # in seconds
    end

    def on_tcp_connection_failure
      failure = "Can not establish connection. TCP connection failure."
      logger.fatal failure
      @connected.fail :tcp_failure, failure
    end

    def on_possible_authentication_failure
      failure  ="Can not establish connection. Possible authentication failure."
      logger.fatal failure
      @connected.fail :auth_failure, failure
    end

    def on_connection_error(connection, connection_close)
      # Connection-level exceptions are rare and may indicate a serious issue with a client library or in-flight data corruption.
      # The AMQP 0.9.1 specification mandates that a connection that has errored cannot be used any more
      # and must be closed. In any case, your application should be prepared to handle this kind of error.
      # To define a handler, use AMQP::Session#on_error method that takes a callback and yields two arguments to it
      # when a connection-level exception happens:

      # Handling graceful shutdown
      logger.error "Connection error. Reply code = #{connection_close.reply_code}, reply text = #{connection_close.reply_text}"
      if connection_close.reply_code == 320
        logger.info "Detected server shutdown. Setting up a periodic reconnection timer..."
        # every 30 seconds
        connection.periodically_reconnect(30)
      else
        logger.fatal "Connection error. Bailing out!"
        raise connection_close.reply_text
      end
    end

    def on_tcp_connection_loss(connection, settings)
      # a callback that will be executed once when TCP connection fails.
      # It is possible that reconnection attempts will not succeed immediately,
      # so there will be subsequent failures. To react to those see
      # #on_connection_interruption
      # reconnect in 2 seconds, without enforcement
      logger.warn "TCP connection loss. Reconnecting..."
      connection.periodically_reconnect(reconnection_period)
    end

    def on_connection_interruption(connection)
      # Note that AMQP::Session#on_connection_interruption callback is called
      # before this event is propagated to channels, queues and so on.
      # Different applications handle connection failures differently.
      # It is very common to use AMQP::Session#reconnect method to schedule a reconnection to the same host,
      # or use AMQP::Session#reconnect_to to connect to a different one.
      # For some applications it is OK to simply exit and wait to be restarted at a later point in time,
      # for example, by a process monitoring system like Nagios or Monit.
      logger.warn "Connection detected connection interruption. Reconnecting..."
      connection.periodically_reconnect(reconnection_period)
    end

    def log_connection_success(connection)
      logger.info "Connected to #{connection.hostname}:#{connection.port}/#{connection.vhost}"
      logger.debug "Client properties:"
      logger.debug connection.client_properties.inspect
      logger.debug "Server properties:"
      logger.debug connection.server_properties.inspect
      logger.debug "Server capabilities:"
      logger.debug connection.server_capabilities.inspect
      logger.debug "Broker product: #{connection.broker.product}, version: #{connection.broker.version}"
      logger.debug "Connected to RabbitMQ? #{connection.broker.rabbitmq?}"
      logger.debug "Broker supports publisher confirms? #{connection.broker.supports_publisher_confirmations?}"
      logger.debug "Broker supports basic.nack? #{connection.broker.supports_basic_nack?}"
      logger.debug "Broker supports consumer cancel notifications? #{connection.broker.supports_consumer_cancel_notifications?}"
      logger.debug "Broker supports exchange-to-exchange bindings? #{connection.broker.supports_exchange_to_exchange_bindings?}"
    end

  end

end