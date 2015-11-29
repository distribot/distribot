
module Distribot

  class TaskFinishedHandler
    attr_accessor :consumer

    def initialize(workflow_id, queue_name, handler)
      workflow = Distribot::Workflow.find(workflow_id)
      counter_key = queue_name.gsub('.finished', '')
      self.consumer = Distribot.subscribe_multi(queue_name) do |_, _, payload|
        Distribot.redis.decr counter_key
        if Distribot.redis.get(counter_key).to_i <= 0
          Distribot.publish! 'distribot.workflow.handler.finished', {
            workflow_id: workflow_id,
            phase: Distribot::Workflow.find(workflow_id).current_phase,
            handler: handler
          }.to_json
          self.cancel(queue_name)
        end
      end
    end

    def cancel(queue_name)
#puts "Cancelling consumer of #{queue_name}"
      self.consumer.cancel
    end
  end

end
