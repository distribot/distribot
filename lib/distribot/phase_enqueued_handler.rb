
module Distribot

  class PhaseEnqueuedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.phase.enqueued', fanout: true, handler: :callback

    def callback(message)
pp self.class => message
      TaskFinishedHandler.new( message[:workflow_id], message[:queue_name] + '.finished', message[:handler] )
    end
  end

end
