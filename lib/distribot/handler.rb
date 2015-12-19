
module Distribot
  module Handler
    attr_accessor :queue_name, :consumers

    def self.included(base)
      base.extend ClassMethods
    end

    def initialize
      self.consumers = []
      self.queue_name = self.class.queue
      handler = self.class.handler
      Distribot.subscribe(queue_name, self.class.subscribe_args) do |message|
        send(handler, message)
      end
    end

    def self.handler_for(klass)
      klass.handler
    end

    def self.queue_for(klass)
      klass.queue
    end

    module ClassMethods
      class << self
        attr_accessor :queue, :handler, :subscribe_args
      end

      def subscribe_to(queue_name, handler_args)
        @queue = queue_name
        @handler = handler_args.delete :handler
        @subscribe_args = handler_args
      end

      def handler
        @handler
      end

      def queue
        @queue
      end

      def subscribe_args
        @subscribe_args
      end
    end
  end
end
