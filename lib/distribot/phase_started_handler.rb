
module Distribot

  class PhaseStartedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.phase.started', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find( message[:workflow_id] )
      phase = workflow.phase( workflow.current_phase )

      if phase.handlers.empty?
        Distribot.publish! 'distribot.workflow.phase.finished', {
          workflow_id: workflow.id,
          phase: phase.name
        }.to_json
      else
        phase.handlers.map do |handler|
          queue_name = "distribot.workflow.#{workflow.id}.#{phase.name}.#{handler}.tasks"
          # Announce that we need some workers to listen to the task queue:
          Distribot.publish! 'distribot.workflow.handler.started', {
            handler: handler,
            workflow_id: workflow.id,
            queue_name: queue_name
          }.to_json
        end
      end
    end
  end

end
