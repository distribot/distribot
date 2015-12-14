
module Distribot
  module Handler
    @@queues = { }
    @@handlers = { }
    @@subscribe_args = { }

    def self.handler_for(klass)
      @@handlers[klass.to_s]
    end

    def self.queue_for(klass)
      @@queues[klass.to_s]
    end

    def self.included(klass)
      klass.class_eval do
        attr_accessor :queue_name, :consumers
        def self.subscribe_to(queue_name, handler_args)
          @@queues[self.to_s] = queue_name
          @@handlers[self.to_s] = handler_args.delete :handler
          @@subscribe_args[self.to_s] = handler_args
        end
        def initialize
          self.consumers = [ ]
          self.queue_name = @@queues[self.class.to_s]
          Distribot.subscribe(self.queue_name, @@subscribe_args[self.class.to_s]) do |message|
            self.send(@@handlers[self.class.to_s], message)
          end
        end
        def logger
          Distribot.logger
        end
      end
    end
  end
end
