
require 'active_support/core_ext/object'
require 'active_support/json'
require 'bunny'

module Distribo

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

  def self.debug=(value)
    @@debug = value ? true : false
  end
  def self.debug
    @@debug ||= false
  end
end
