
require 'active_support/core_ext/object'
require 'active_support/json'
require 'bunny'
require 'redis'

require 'distribot/workflow'
require 'distribot/phase'
require 'distribot/handler'
require 'distribot/workflow_created_handler'
require 'distribot/phase_enqueued_handler'
require 'distribot/task_finished_handler'
require 'distribot/handler_finished_handler'
require 'distribot/phase_finished_handler'
require 'distribot/workflow_finished_handler'

module Distribot

  @@config = OpenStruct.new()
  @@did_configure = false

  def self.configure(&block)
    @@did_configure = true
    block.call(configuration)
    # Now set defaults for things that aren't defined:
    configuration.redis_prefix ||= 'distribot'
    configuration.queue_prefix ||= 'distribot'
  end

  def self.configuration
    unless @@did_configure
      self.configure do
      end
    end
    @@config
  end

  def self.bunny
    @@bunny ||= Bunny.new( configuration.rabbitmq_url )
  end

  def self.queue_exists?(name)
    bunny.queue_exists?(name)
  end

  def self.bunny_channel
    unless defined? @@channel
      bunny.start
    end
    @@channel ||= bunny.create_channel
    @@channel
  end

  def self.redis
    # Redis complains if we pass it a nill url. Better to not pass a url at all:
    @@redis ||= configuration.redis_url ? Redis.new( configuration.redis_url ) : Redis.new
  end

  def self.debug=(value)
    @@debug = value ? true : false
  end

  def self.debug
    @@debug ||= false
  end

  def self.redis_id(type, id)
    "#{configuration.redis_prefix}-#{type}:#{id}"
  end

  def self.queue(name)
    bunny_channel.queue(name, auto_delete: true, durable: true)
  end

  def self.publish!(queue_name, json)
    queue_obj = queue(queue_name)
    bunny_channel.default_exchange.publish json, routing_key: queue_obj.name
  end

  def self.fanout_exchange
    @@fanout ||= bunny.create_channel.fanout('yay')
  end

  def self.subscribe_multi(queue_name, &block)
    queue_obj = queue(queue_name)
    queue_obj.bind( fanout_exchange ).subscribe do |delivery_info, properties, payload|
      block.call(delivery_info, properties, payload)
    end
  end

  def self.broadcast!(queue_name, json)
    queue_obj = queue(queue_name)
    fanout_exchange.publish json, routing_key: queue_obj.name
  end
end
