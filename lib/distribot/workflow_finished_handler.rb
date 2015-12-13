
module Distribot
  class WorkflowFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
      Distribot.redis.decr('distribot.workflows.running')
      Distribot.redis.publish "distribot.workflow.#{workflow.id}.finished.callback", {
        workflow_id: workflow.id
      }.to_json
    end
  end
end
