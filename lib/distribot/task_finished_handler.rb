
module Distribot

  class TaskFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.handler.enumerated', handler: :callback

    def callback(message)
      @consumers ||= [ ]
      @consumers << Distribot.subscribe(message[:finished_queue]) do |task_info|
        handle_task_finished(message, task_info)
      end
    end

    def handle_task_finished(message, task_info)
      task_counter = message[:task_queue]
      current_value = Distribot.redis.get(task_counter)
      unless current_value.nil?
        new_value = Distribot.redis.decr task_counter
puts "DECR: #{current_value} -> #{new_value}"
        if new_value.to_i <= 0
          Distribot.publish! 'distribot.workflow.handler.finished', {
            workflow_id: message[:workflow_id],
            phase: message[:phase],
            handler: message[:handler],
            task_queue: message[:task_queue]
          }
          gonners = @consumers.select{|x| x.queue.name == message[:finished_queue]}
          @consumers -= gonners
          gonners.uniq{|x| x.queue.name }.map(&:cancel)
        end
      end
    end
  end
end
