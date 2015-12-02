
require 'active_support/core_ext/object'
require 'active_support/json'
require 'bunny'
require 'redis'

require 'distribot/workflow'
require 'distribot/phase'
require 'distribot/handler'
require 'distribot/workflow_created_handler'
require 'distribot/phase_started_handler'
require 'distribot/worker'
require 'distribot/task_finished_handler'
require 'distribot/handler_finished_handler'
require 'distribot/phase_finished_handler'
require 'distribot/workflow_finished_handler'

module Distribot

  @@config = OpenStruct.new()
  @@did_configure = false
  @@bunnies = { }

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
    key = Thread.current.to_s
    if @@bunnies.has_key?(key)
      return @@bunnies[key]
    else
      thread_bunny = @@bunnies[key] = Bunny.new( configuration.rabbitmq_url )
      thread_bunny.start
      return thread_bunny
    end
  end

  def self.queue_exists?(name)
    bunny.queue_exists?(name)
  end

  def self.bunny_channel(topic)
    @@channel ||= bunny.create_channel
  end

  def self.redis
    # Redis complains if we pass it a nil url. Better to not pass a url at all:
    @@redis ||= configuration.redis_url ? Redis.new( url: configuration.redis_url ) : Redis.new
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
    bunny_channel(name).queue(name, auto_delete: true, durable: true)
  end

  def self.publish!(queue_name, data)
    queue_obj = queue(queue_name)
    bunny_channel(name).default_exchange.publish data.to_json, routing_key: queue_name
  end

  def self.subscribe(queue_name, options={}, &block)
puts "SUBSCRIBE(#{queue_name})"
    ch = bunny_channel(name)
#    ch.prefetch(1)
    queue_obj = ch.queue(queue_name, auto_delete: true, durable: true)
    queue_obj.subscribe(options.merge(manual_ack: true)) do |delivery_info, properties, payload|
      block.call(JSON.parse(payload, symbolize_names: true))
      ch.acknowledge(delivery_info.delivery_tag, false)
    end
  end

  def self.broadcast!(topic, data)
puts "broadcast"
    ch = bunny_channel(name)
    x = ch.fanout("distribot.fanout.#{topic}")
    x.publish(data.to_json, routing_key: topic)
  end

  def self.subscribe_multi(topic, &block)
puts "subscribe_multi"
    ch = bunny_channel(name)
    ch.prefetch(1)
    my_queue = ch.queue('', exclusive: true, auto_delete: true)
    x = ch.fanout("distribot.fanout.#{topic}")
    my_queue.bind(x).subscribe do |delivery_info, properties, payload|
      block.call(JSON.parse(payload, symbolize_names: true))
    end
  end

end
