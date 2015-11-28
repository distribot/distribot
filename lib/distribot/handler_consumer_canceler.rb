
module Distribot
  class HandlerConsumerCanceler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.cancel.consumers', fanout: true, handler: :callback

    def callback(message)
      HandlerRunner.cancel_consumers_for(message[:queue])
    end
  end
end
