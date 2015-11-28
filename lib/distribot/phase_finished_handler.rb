
module Distribot
  class PhaseFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.phase.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
      if workflow.current_phase == message[:phase]
        if workflow.next_phase
puts "WORKFLOW #{workflow.name}: Transition To #{workflow.next_phase}"
          workflow.transition_to! workflow.next_phase
        else
          # This workflow is finished - send it on down the line!
          Distribot.publish! 'distribot.workflow.finished', {
            workflow_id: workflow.id
          }.to_json
        end
      end
    end
  end
end
