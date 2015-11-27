
module Distribot

  class PhaseEnqueuedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.phase.enqueued', handler: :callback

    def callback(message)
      TaskFinishedHandler.new( message[:workflow_id], message[:queue_name] + '.finished', message[:handler] )
    end
  end

end
