
module Distribot

  class WorkflowCreatedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.created', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find( message[:workflow_id] )
puts "\n\nWORKFLOW #{workflow.name} STARTED!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n\n"
      workflow.transition_to! workflow.next_phase
    end
  end

end
