
module Distribot
  module Handler
    @@queues = { }
    @@handlers = { }
    @@subscribe_args = { }

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
          @@handlers[self] = handler_args.delete :handler
          @@subscribe_args[self] = handler_args
        end
        def initialize
          self.queue_name = @@queues[self.class]
          Distribot.subscribe(self.queue_name, @@subscribe_args[self.class]) do |message|
            self.send(@@handlers[self.class], message)
          end
        end
      end
    end
  end
end
