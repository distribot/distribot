
module Distribot

  class TaskFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.task.finished', handler: :callback

    def callback(message)
      task_counter_key = self.task_counter(message)
      current_value = Distribot.redis.get(task_counter_key)
      if current_value.nil?
        # NOTHING:
      elsif current_value.to_i > 0
        new_value = Distribot.redis.decr task_counter_key
        if new_value.to_i == 0
          Distribot.redis.del(task_counter_key)
          Distribot.publish! 'distribot.workflow.handler.finished', {
            workflow_id: message[:workflow_id],
            phase: message[:phase],
            handler: message[:handler],
            task_queue: message[:task_queue]
          }
        end
      end
    end

    def task_counter(message)
      "distribot.workflow.#{message[:workflow_id]}.#{message[:phase]}.#{message[:handler]}.finished"
    end
  end
end
