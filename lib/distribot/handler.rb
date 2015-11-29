
module Distribot
  module Handler
    @@queues = { }
    @@handlers = { }
    @@fanouts = [ ]

    def self.handler_for(klass)
      @@handlers[klass]
    end

    def self.queue_for(klass)
      @@queues[klass]
    end

    def self.included(klass)
      klass.class_eval do
        attr_accessor :queue_name
        def self.subscribe_to(queue_name, handler_args)
          @@queues[self] = queue_name
          @@handlers[self] = handler_args[:handler]
          @@fanouts << self if handler_args[:fanout]
        end
        def initialize
          self.queue_name = @@queues[self.class]
          if @@fanouts.include? self.class
puts "#{self}.subscribe_multi(#{self.queue_name})"
            Distribot.subscribe_multi(self.queue_name) do |message|
puts "#{self.class}.received_multi(#{self.queue_name}, #{message})"
              self.send(@@handlers[self.class], message)
            end
          else
puts "#{self}.subscribe(#{self.queue_name})"
            Distribot.subscribe(self.queue_name) do |message|
puts "#{self.class}.received(#{self.queue_name}, #{message})"
              self.send(@@handlers[self.class], message)
            end
          end
        end
      end
    end
  end
end
