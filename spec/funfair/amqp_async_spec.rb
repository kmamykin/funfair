require 'spec_helper'

describe Funfair do
  include EventedSpec::SpecHelper
  default_timeout 20

  let(:client) { Funfair::Client.new({}) }

  def event_name(n=nil)
    base_name = example.description.strip.downcase.tr(' ', '_')
    n ? "#{base_name}_#{n}" : base_name
  end

  def subscriber_queue(n=nil)
    base_name = example.description.strip.downcase.tr(' ', '_')
    n ? "#{base_name}_#{n}" : base_name
  end

  describe 'pubsub publishing' do
    it 'should ack one publish requests even without subscribers' do
      em do
        pub_request = client.pubsub.publish(event_name, {})
        pub_request.callback { client.disconnect { done } }
        pub_request.errback { |message| fail message }
      end
    end

    it 'should ack many requests' do
      number_of_requests = 100
      em do
        published = 0
        check_if_all_published = Proc.new do
          published += 1
          if published == number_of_requests
            client.pubsub.delete_all do
              client.disconnect do
                done
              end
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
          client.pubsub.delete_all do
            client.disconnect do
              done
            end
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
            client.pubsub.delete_all do
              client.disconnect do
                done
              end
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
            client.pubsub.delete_all do
              client.disconnect do
                done
              end
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
end
