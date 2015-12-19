
require 'active_support/core_ext/object'
require 'active_support/json'
require 'redis'
require 'distribot/workflow'
require 'distribot/phase'
require 'distribot/phase_handler'
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
require 'logstash-logger'

module Distribot
  class << self
    attr_accessor :config, :did_configure, :connector, :redis, :debug, :logger
    @config = OpenStruct.new
    @did_configure = false
    @connector = nil

    def reset_configuration!
      self.config = OpenStruct.new
      self.did_configure = false
      self.redis = nil
    end

    def configure(&block)
      reset_configuration!
      @did_configure = true
      block.call(configuration)
      # Now set defaults for things that aren't defined:
      configuration.redis_prefix ||= 'distribot'
      configuration.queue_prefix ||= 'distribot'
    end

    def connector
      @connector ||= BunnyConnector.new(configuration.rabbitmq_url)
    end

    def configuration
      unless @did_configure
        reset_configuration!
        configure do |config|
          config.redis_url = ENV['DISTRIBOT_REDIS_URL']
          config.rabbitmq_url = ENV['DISTRIBOT_RABBITMQ_URL']
        end
      end
      self.config
    end

    def queue_exists?(name)
      connector.queue_exists?(name)
    end

    def redis
      # Redis complains if we pass it a nil url. Better to not pass a url:
      @redis ||= if configuration.redis_url
                   Redis.new(url: configuration.redis_url)
                 else
                   Redis.new
                 end
    end

    def debug=(value)
      @debug = value ? true : false
    end

    def debug
      @debug ||= false
    end

    def redis_id(type, id)
      "#{configuration.redis_prefix}-#{type}:#{id}"
    end

    def publish!(topic, data)
      connector.publish(topic, data)
    end

    def subscribe(topic, options = {}, &block)
      connector.subscribe(topic, options) do |message|
        block.call(message)
      end
    end

    def broadcast!(topic, data)
      connector.broadcast(topic, data)
    end

    def subscribe_multi(topic, options = {}, &block)
      connector.subscribe_multi(topic, options) do |message|
        block.call(message)
      end
    end

    def logger
      @logger ||= LogStashLogger.new(type: :syslog, formatter: :json)
      @logger
    end
  end
end
