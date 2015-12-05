
module Distribot

  class TaskFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.handler.enumerated', handler: :callback

    def callback(message)
      self.consumers << Distribot.subscribe(message[:finished_queue]) do |task_info|
        handle_task_finished(message, task_info)
      end
    end

    def handle_task_finished(message, task_info)
      task_counter = message[:task_queue]
      current_value = Distribot.redis.get(task_counter)
      unless current_value.nil?
        new_value = Distribot.redis.decr task_counter
        if new_value.to_i <= 0
          Distribot.publish! 'distribot.workflow.handler.finished', {
            workflow_id: message[:workflow_id],
            phase: message[:phase],
            handler: message[:handler],
            task_queue: message[:task_queue]
          }
          cancel_consumers_for(message[:finished_queue])
        end
      end
    end

    def cancel_consumers_for(finished_queue)
      gonners = self.consumers.select{|x| x.queue.name == finished_queue}
      self.consumers -= gonners
      gonners.uniq{|x| x.queue.name }.map(&:cancel)
    end
  end
end
