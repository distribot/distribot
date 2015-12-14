
require 'active_support/core_ext/object'
require 'active_support/json'
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
require 'distribot/connector'
require 'syslog/logger'

module Distribot

  @@config = OpenStruct.new()
  @@did_configure = false
  @@connector = nil

  def self.configure(&block)
    @@did_configure = true
    block.call(configuration)
    # Now set defaults for things that aren't defined:
    configuration.redis_prefix ||= 'distribot'
    configuration.queue_prefix ||= 'distribot'
  end

  def self.connector
    @@connector ||= BunnyConnector.new(configuration.rabbitmq_url)
  end

  def self.configuration
    unless @@did_configure
      self.configure do |config|
        config.redis_url = ENV['DISTRIBOT_REDIS_URL']
        config.rabbitmq_url = ENV['DISTRIBOT_RABBITMQ_URL']
      end
    end
    @@config
  end

  def self.queue_exists?(name)
    connector.queue_exists?(name)
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

  def self.publish!(topic, data)
    connector.publish(topic, data)
  end

  def self.subscribe(topic, options={}, &block)
    connector.subscribe(topic, options) do |message|
      block.call( message )
    end
  end

  def self.broadcast!(topic, data)
    connector.broadcast(topic, data)
  end

  def self.subscribe_multi(topic, options={}, &block)
    connector.subscribe_multi(topic, options) do |message|
      block.call( message )
    end
  end

  def self.logger
    @@logger ||= Syslog::Logger.new('distribot')
@@logger.level = Logger::DEBUG
#    @@logger.level = ENV['DEBUG'].to_s == 'true' ? Logger::DEBUG : Logger::INFO
    @@logger
  end

end
