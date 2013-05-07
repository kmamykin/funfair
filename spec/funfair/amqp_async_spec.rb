require 'spec_helper'

describe Funfair do
  include EventedSpec::SpecHelper
  default_timeout 5

  before :all do
    Funfair.configure do |config|
      #config.connection_options_or_string = ''
      config.namespace = 'test'
      #config.log_level = Logger::DEBUG
    end
  end

  let(:client) { Funfair.client }

  describe 'configuration of subscribers' do
    it 'should declare subscribers for each event' do
      class Sub1
        include Funfair::Subscriber
        on :event1, :event2 do |evt|
        end
      end

      Funfair.configure do |config|
        config.subscribers = [Sub1]
      end

      pubsub = double('pubsub')
      pubsub.should_receive(:subscribe).with('event1', 'test.Sub1.event1')
      pubsub.should_receive(:subscribe).with('event2', 'test.Sub1.event2')
      Funfair.configuration.declare(pubsub)
    end
  end

  describe 'pubsub publishing' do
    it 'should ack publish requests to existing subscribers' do
       em do
        client.pubsub.subscribe(event_name, subscriber_queue) do |event_data|
          event_data.should == 'Called'
          client.disconnect{ done }
        end
        client.pubsub.on_ready do
          client.pubsub.publish(event_name, 'Called')
        end
      end
    end

    it 'should ack many requests' do
      number_of_requests = 100
      em do
        published = 0
        check_if_all_published = Proc.new do
          published += 1
          if published == number_of_requests
            client.disconnect do
              done
            end
          end
        end
        number_of_requests.times do |n|
          pub_request = client.pubsub.publish(event_name)
          pub_request.callback &check_if_all_published
          pub_request.errback { |message| fail message }
        end
      end
    end
  end

  describe 'integration' do

    it 'should subscribe and publish async' do
      em do
        client.pubsub.subscribe(event_name, subscriber_queue) do
          client.disconnect do
            done
          end
        end
        client.pubsub.on_ready do
          pub_request = client.pubsub.publish(event_name, "Data")
          pub_request.callback {}
          pub_request.errback { |message| fail message }
        end
      end
    end

    it 'should handle many subscribers' do
      number_of_subscribers = 100
      em do
        received = 0
        check_if_all_received = Proc.new do |payload|
          received += 1
          if received == number_of_subscribers
            client.disconnect do
              done
            end
          end
        end
        # subscribe multiple consumers to one exchange
        number_of_subscribers.times do |n|
          client.pubsub.subscribe(event_name, subscriber_queue(n), &check_if_all_received)
        end
        # publish once
        client.pubsub.on_ready do
          pub_request = client.pubsub.publish(event_name)
          pub_request.callback {}
          pub_request.errback { |message| fail message }
        end
      end
    end

    it 'should handle many publishers' do
      number_of_publishers = 100
      em do
        received = 0
        check_if_all_received = Proc.new do
          received += 1
          if received == number_of_publishers
            client.disconnect do
              done
            end
          end
        end
        # subscribe multiple consumers to multiple exchange 1:1
        number_of_publishers.times do |n|
          client.pubsub.subscribe(event_name(n), subscriber_queue(n), &check_if_all_received)
        end
        client.pubsub.on_ready do
          # publish to each exchange
          number_of_publishers.times do |n|
            pub_request = client.pubsub.publish(event_name(n))
            pub_request.callback {}
            pub_request.errback { |message| fail message }
          end
        end
      end
    end
  end

  def event_name(n=nil)
    base_name = example.description.strip.downcase.tr(' ', '_')
    n ? "#{base_name}_#{n}" : base_name
  end

  def subscriber_queue(n=nil)
    base_name = example.description.strip.downcase.tr(' ', '_')
    n ? "#{base_name}_#{n}" : base_name
  end

end
