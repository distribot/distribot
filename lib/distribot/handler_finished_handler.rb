
module Distribot

  class HandlerFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.handler.finished', handler: :callback

    def callback(message)
      # Figure out all this workflow's task queue counters:
      workflow = Distribot::Workflow.find(message[:workflow_id])

      # This is a message that goes out globally?
      cancel_consumers_for = "distribot.workflow.#{workflow.id}.#{message[:phase]}.#{message[:handler]}.tasks"
      Distribot.broadcast! 'distribot.workflow.cancel.consumers', {
        queue: cancel_consumers_for
      }.to_json

      # If their counters are all at zero, then this phase is complete:
      counters = workflow.phase(message[:phase]).handlers.map do |handler|
        "distribot.workflow.#{workflow.id}.#{message[:phase]}.#{handler}.tasks"
      end
      if counters.select{|counter_key| Distribot.redis.get(counter_key).to_i > 0 }.empty?
        Distribot.publish! 'distribot.workflow.phase.finished', {
          workflow_id: workflow.id,
          phase: message[:phase]
        }.to_json
      end
    end
  end

end
