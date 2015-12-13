
module Distribot
  class WorkflowFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
      Distribot.redis.decr('distribot.workflows.running')
puts "PUBLISHGIGN ---------------------------- "
      Distribot.redis.publish "distribot.workflow.#{workflow.id}.finished.callback", {
        workflow_id: workflow.id
      }.to_json
puts "^^^^^^^^^^ DONE &&&&&&&&&&&&&&&&&&&&&&&&&&&&"
#      if Distribot.queue_exists?("distribot.workflow.#{workflow.id}.finished.callback")
        # Distribot.publish! "distribot.workflow.#{workflow.id}.finished.callback", {
        #   workflow_id: workflow.id
        # }
#      end
    end
  end
end
