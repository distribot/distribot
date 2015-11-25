
require 'active_support/core_ext/object'
require 'active_support/json'
require 'bunny'
require 'redis'

require 'distribot/workflow'
require 'distribot/phase'

module Distribot

  @@config = OpenStruct.new()

  def self.configure(&block)
    block.call(@@config)
  end

  def self.configuration
    @@config
  end

  def self.bunny
    @@bunny ||= Bunny.new( configuration.rabbitmq_url )
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
end
