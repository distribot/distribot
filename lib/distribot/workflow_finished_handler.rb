
module Distribot
  class WorkflowFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
puts "\n\nWORKFLOW #{workflow.name} FINISHED!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n\n"
      if Distribot.queue_exists?("distribot.workflow.#{workflow.id}.finished")
        Distribot.publish! "distribot.workflow.#{workflow.id}.finished", {
          workflow_id: workflow.id
        }.to_json
      end
      # TODO: mark this workflow as 'finished'
      # Maybe via Sidekiq.
    end
  end
end
