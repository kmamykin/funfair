require 'logger'
require 'amqp'
require 'amqp/extensions/rabbitmq'
require 'amqp/utilities/event_loop_helper'
require "funfair/version"
require "funfair/configuration"
require "funfair/client"
require 'funfair/pub_sub'
require 'funfair/confirmed_publisher'
require 'funfair/publish_request'
require 'funfair/subscriber'
require 'funfair/subscribers'
require 'funfair/worker'

module Funfair
  # Your code goes here...

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.logger
    configuration.logger
  end
end
