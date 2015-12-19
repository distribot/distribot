
module Distribot

  class PhaseFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.phase.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find( message[:workflow_id] )
      if workflow.current_phase == message[:phase]
        next_phase = workflow.next_phase
        if next_phase.nil?
          Distribot.publish! 'distribot.workflow.finished', {
            workflow_id: workflow.id
          }
        else
          workflow.transition_to! next_phase
        end
      else
        # Do nothing. We have received a message that's out of date, apparently.
      end
    end
  end

end
