
module Distribot
  class PhaseFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.phase.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
      return unless workflow.current_phase == message[:phase]
      if workflow.next_phase
        workflow.transition_to! workflow.next_phase
      else
        Distribot.publish!(
          'distribot.workflow.finished', workflow_id: workflow.id
        )
      end
    end
  end
end
