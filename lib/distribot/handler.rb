
module Distribot
  module Handler

    attr_accessor :queue_name, :consumers

    def self.included(base)
      base.extend ClassMethods
    end

    def initialize
      self.consumers = [ ]
      self.queue_name = self.class.queue
      handler = self.class.handler
      Distribot.subscribe(self.queue_name, self.class.subscribe_args) do |message|
        self.send(handler, message)
      end
    end

    def self.handler_for(klass)
      klass.handler
    end

    def self.queue_for(klass)
      klass.queue
    end

    module ClassMethods

      @@queues = { }
      @@handlers = { }
      @@subscribe_args = { }

      def subscribe_to(queue_name, handler_args)
        @@queues[self] = queue_name
        @@handlers[self] = handler_args.delete :handler
        @@subscribe_args[self] = handler_args
      end

      def handler
        @@handlers[self]
      end

      def queue
        @@queues[self]
      end

      def subscribe_args
        @@subscribe_args[self]
      end
    end
  end
end
