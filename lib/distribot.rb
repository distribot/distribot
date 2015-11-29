
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
require 'distribot/phase_finished_handler'
require 'distribot/workflow_finished_handler'

module Distribot

  @@config = OpenStruct.new()
  @@did_configure = false
  @@fanouts = { }

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
    failed = false
    while true do
      begin
        queue = bunny_channel.queue(name, auto_delete: true, durable: true)
warn "SUCCEEDED!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" if failed
        return queue
      rescue StandardError => e
puts "FAILED..."
        failed = true
        sleep 0.1
        next
      end
    end
  end

  def self.publish!(queue_name, data)
pp publish: queue_name, data: data
    while true do
      begin
        queue_obj = queue(queue_name)
        bunny_channel.default_exchange.publish data.to_json, routing_key: queue_obj.name
        break
      rescue StandardError => e
        puts "ERROR in publish! #{e} --- #{e.backtrace.join("\n")}"
        sleep 0.1
      end
    end
  end

  def self.fanout_exchange(name)
    @@fanouts[name||''] ||= bunny.create_channel.fanout(name || '')
  end

  def self.subscribe(queue_name, &block)
pp subscribe: queue_name
    queue_obj = queue(queue_name)
    queue_obj.subscribe do |delivery_info, properties, payload|
      block.call(JSON.parse(payload, symbolize_names: true))
    end
  end

  def self.subscribe_multi(queue_name, &block)
    my_queue = bunny_channel.queue(queue_name)
    exchange = bunny_channel.fanout('distribot.fanout')
    my_queue.bind(exchange).subscribe do |delivery_info, properties, payload|
      block.call(JSON.parse(payload, symbolize_names: true))
    end
  end

  def self.broadcast!(queue_name, data)
    ch = bunny.create_channel
    x = ch.fanout('distribot.fanout')
    x.publish(data.to_json, routing_key: queue_name)
  end

end
