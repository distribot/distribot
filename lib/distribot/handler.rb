
module Distribot
  module Handler
    @@queues = { }
    @@handlers = { }

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
        end
        def initialize
          self.queue_name = @@queues[self.class]
          Distribot.queue(self.queue_name).subscribe do |_, _, payload|
#pp 'payload(distribot.workflow.created)' => payload
            message = JSON.parse(payload, symbolize_names: true)
            self.send(@@handlers[self.class], message)
          end
        end
      end
    end
  end
end
