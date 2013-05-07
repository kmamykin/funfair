require 'logger'
require 'amqp'
require 'amqp/extensions/rabbitmq'
require 'amqp/utilities/event_loop_helper'
require "funfair/version"
require "funfair/configuration"
require 'funfair/pub_sub/pub_sub'
require 'funfair/pub_sub/confirmed_publisher'
require 'funfair/pub_sub/publish_request'
require 'funfair/pub_sub/subscription'
require 'funfair/pub_sub/subscribers'
require "funfair/subscriber"
require "funfair/publisher"
require "funfair/client"
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

  def self.client
    @client
  end

  # return a new client and initiates a connect
  def self.connect
    @client = Client.new(self.configuration).tap do |client|
      client.connect
    end
  end
end
