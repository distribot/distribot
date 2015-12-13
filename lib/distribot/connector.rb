
require 'pp'
require 'securerandom'
require 'bunny'
require 'byebug'
require 'active_support/json'

module Distribot

  class Connector
    attr_accessor :connection_args, :bunny, :channel
    def initialize(connection_args={})
      self.connection_args = connection_args
      self.bunny = Bunny.new(self.connection_args)
      self.bunny.start
      self.channel = self.bunny.create_channel
      self.channel.prefetch(1)
    end
  end

  class ConnectionSharer
    attr_accessor :bunny, :channel
    def initialize(bunny)
      self.bunny = bunny
      self.channel = self.bunny.create_channel
    end
  end

  class Subscription < ConnectionSharer
    attr_accessor :consumer
    def start(topic, options={}, &block)
      queue = self.channel.queue(topic, auto_delete: true, durable: true)
      self.consumer = queue.subscribe(options.merge(manual_ack: true)) do |delivery_info, properties, payload|
        begin
          parsed_message = JSON.parse(payload, symbolize_names: true)
          block.call( parsed_message )
          self.channel.acknowledge(delivery_info.delivery_tag, false)
        rescue StandardError => e
          puts "ERROR: #{e} -- #{e.backtrace.join("\n")}"
          self.channel.basic_reject(delivery_info.delivery_tag, true)
        end
      end
    end

    def cancel
      self.consumer.cancel
      self.channel.close
    end
  end

  class MultiSubscription < ConnectionSharer
    def start(topic, options={}, &block)
      private_queue = self.channel.queue('', exclusive: true, auto_delete: true)
      exchange = self.channel.fanout(topic)
      private_queue.bind(exchange).subscribe(options) do |delivery_info, properties, payload|
        begin
          block.call(JSON.parse(payload, symbolize_names: true))
        rescue StandardError => e
          puts "Error #{e} with #{payload} --- #{e.backtrace.join("\n")}"
        end
      end
    end
  end

  class BunnyConnector < Connector
    attr_accessor :subscribers, :multi_subscribers
    def initialize(*args)
      super(*args)
      self.subscribers = [ ]
      self.multi_subscribers = [ ]
      self.bunny = Bunny.new(self.connection_args)
      self.bunny.start
      self.channel = self.bunny.create_channel
    end

    def queue_exists?(topic)
      self.bunny.queue_exists?(topic)
    end

    def subscribe(topic, options={}, &block)
      subscriber = Subscription.new(self.bunny)
      subscriber.start(topic, options) do |message|
        block.call( message )
      end
    end

    def subscribe_multi(topic, options={}, &block)
      subscriber = MultiSubscription.new(self.bunny)
      subscriber.start(topic, options) do |message|
        block.call( message )
      end
    end

    def publish(topic, message)
      queue = stubbornly :get_queue do
        self.channel.queue(topic, auto_delete: true, durable: true)
      end
      self.channel.default_exchange.publish message.to_json, routing_key: topic
    end

    def broadcast(topic, message)
      exchange = self.channel.fanout(topic)
      exchange.publish(message.to_json, routing_key: topic)
    end

    private
    def stubbornly task, &block
      result = nil
      while true do
        begin
          result = block.call
          break
        rescue Timeout::Error => e
#          warn "Error during #{task}: #{e} --- #{e.backtrace.join("\n")}"
          sleep 1
          next
        end
      end
      result
    end
  end
end
