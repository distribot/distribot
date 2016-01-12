
module Distribot
  class HandlerFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.flow.handler.finished', handler: :callback

    def callback(message)
      flow = Distribot::Flow.find(message[:flow_id])
      phase = flow.phase(message[:phase])

      Distribot.publish!(
        'distribot.flow.phase.finished',
        flow_id: flow.id,
        phase: phase.name
      ) if self.all_phase_handler_tasks_are_complete?(flow, phase)
    end

    def all_phase_handler_tasks_are_complete?(flow, phase)
      redis = Distribot.redis
      name = phase.name
      phase.handlers
        .map { |h| "distribot.flow.#{flow.id}.#{name}.#{h}.tasks" }
        .map { |task_counter_key| redis.get(task_counter_key) }
        .reject(&:nil?)
        .select { |val| val.to_i > 0 }
        .empty?
    end
  end
end
