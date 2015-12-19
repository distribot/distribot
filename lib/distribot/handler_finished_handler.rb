
module Distribot
  class HandlerFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.handler.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
      phase = workflow.phase(message[:phase])

      Distribot.publish!(
        'distribot.workflow.phase.finished',
        workflow_id: workflow.id,
        phase: phase.name
      ) if self.all_phase_handler_tasks_are_complete?(workflow, phase)
    end

    def all_phase_handler_tasks_are_complete?(workflow, phase)
      redis = Distribot.redis
      name = phase.name
      phase.handlers
        .map { |h| "distribot.workflow.#{workflow.id}.#{name}.#{h}.tasks" }
        .map { |task_counter_key| redis.get(task_counter_key) }
        .reject(&:nil?)
        .select { |val| val.to_i > 0 }
        .empty?
    end
  end
end
