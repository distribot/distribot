
module Distribot
  class WorkflowFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
      workflow.phases.each do |phase|
        phase.handlers.each do |handler|
          task_queue = "distribot.workflow.#{workflow.id}.#{phase.name}.#{handler}.tasks"
          Distribot.broadcast! 'distribot.cancel.consumer', {
            task_queue: task_queue
          }
        end
      end
      Distribot.redis.decr('distribot.workflows.running')
      if Distribot.queue_exists?("distribot.workflow.#{workflow.id}.finished.callback")
        Distribot.publish! "distribot.workflow.#{workflow.id}.finished.callback", {
          workflow_id: workflow.id
        }
      end
    end
  end
end
