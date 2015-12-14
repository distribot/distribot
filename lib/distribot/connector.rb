
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

    def logger
      Distribot.logger
    end
  end

  class ConnectionSharer
    attr_accessor :bunny, :channel
    def initialize(bunny)
      self.bunny = bunny
      @channel = nil
    end

    def channel
      if @channel.nil?
        @channel = bunny.create_channel
      end
      @channel
    end

    def logger
      Distribot.logger
    end
  end

  class Subscription < ConnectionSharer
    attr_accessor :consumer, :queue
    def start(topic, options={}, &block)
      self.queue = self.channel.queue(topic, auto_delete: true, durable: true)
      self.consumer = queue.subscribe(options.merge(manual_ack: true)) do |delivery_info, properties, payload|
        begin
          parsed_message = JSON.parse(payload, symbolize_names: true)
          block.call( parsed_message )
          self.channel.acknowledge(delivery_info.delivery_tag, false)
        rescue StandardError => e
          logger.error "ERROR: #{e} -- #{e.backtrace.join("\n")}"
          self.channel.basic_reject(delivery_info.delivery_tag, true)
        end
      end
      self
    end
  end

  class MultiSubscription < ConnectionSharer
    attr_accessor :consumer, :queue
    def start(topic, options={}, &block)
      self.queue = self.channel.queue('', exclusive: true, auto_delete: true)
      exchange = self.channel.fanout(topic)
      self.consumer = queue.bind(exchange).subscribe(options) do |delivery_info, properties, payload|
        begin
          block.call(JSON.parse(payload, symbolize_names: true))
        rescue StandardError => e
          logger.error "Error #{e} with #{payload} --- #{e.backtrace.join("\n")}"
        end
      end
      self
    end
  end

  class BunnyConnector < Connector
    attr_accessor :subscribers, :multi_subscribers, :channel
    def initialize(*args)
      super(*args)
      self.subscribers = [ ]
      self.multi_subscribers = [ ]
      self.bunny = Bunny.new(self.connection_args)
      self.bunny.start
    end

    def channel
      @channel ||= self.bunny.create_channel
    end

    def queue_exists?(topic)
      self.bunny.queue_exists?(topic)
    end

    def subscribe(topic, options={}, &block)
      subscriber = Subscription.new(self.bunny)
      self.subscribers << subscriber.start(topic, options) do |message|
        logger.debug "received(#{topic} -> #{message})"
        block.call( message )
      end
    end

    def subscribe_multi(topic, options={}, &block)
      subscriber = MultiSubscription.new(self.bunny)
      self.subscribers << subscriber.start(topic, options) do |message|
        logger.debug "received-multi(#{topic} -> #{message})"
        block.call( message )
      end
    end

    def publish(topic, message)
      queue = stubbornly :get_queue do
        self.channel.queue(topic, auto_delete: true, durable: true)
      end
      logger.debug "publish(#{topic} -> #{message})"
      self.channel.default_exchange.publish message.to_json, routing_key: topic
    end

    def broadcast(topic, message)
      exchange = self.channel.fanout(topic)
      logger.debug "broadcast(#{topic} -> #{message})"
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
          logger.error "Connection timed out during '#{task}' - retrying in 1sec..."
          sleep 1
          next
        end
      end
      result
    end
  end
end
