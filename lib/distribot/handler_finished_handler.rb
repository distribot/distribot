
module Distribot

  class HandlerFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.handler.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
      phase = workflow.phase( message[:phase] )

      if self.all_phase_handler_tasks_are_complete?(workflow, phase)
        Distribot.publish! 'distribot.workflow.phase.finished', {
          workflow_id: workflow.id,
          phase: phase.name
        }
        Distribot.broadcast! 'distribot.cancel.consumer', {
          task_queue: message[:task_queue]
        }
      end
    end

    # TODO: Consider folding this logic somewhere else where it makes more sense.
    def all_phase_handler_tasks_are_complete?(workflow, phase)
      redis = Distribot.redis
      phase.handlers
        .map{|handler| "distribot.workflow.#{workflow.id}.#{phase.name}.#{handler}.tasks" }
        .map{|task_counter_key| redis.get(task_counter_key) }
        .reject(&:nil?)
        .select{|val| val.to_i > 0 }
        .empty?
    end
  end
end
