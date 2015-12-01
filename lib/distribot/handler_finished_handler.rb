
module Distribot

  class HandlerFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.handler.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
      phase = workflow.phase( message[:phase] )
      counter_keys = phase.handlers.map do |handler|
        "distribot.workflow.#{workflow.id}.#{phase.name}.#{handler}.tasks"
      end
      handlers_unfinished = counter_keys
                              .map{|key| Distribot.redis.get(key) }
                              .reject(&:nil?)
                              .select{|val| val.to_i > 0 }

      if handlers_unfinished.empty?
        Distribot.publish! 'distribot.workflow.phase.finished', {
          workflow_id: workflow.id,
          phase: phase.name
        }
        Distribot.broadcast! 'distribot.cancel.consumer', {
          task_queue: message[:task_queue]
        }
      end
    end
  end
end
