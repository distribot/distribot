
module Distribot

  class TaskFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.handler.enumerated', handler: :callback

    def callback(message)
      @consumers ||= [ ]
#      if Distribot.queue_exists?( message[:finished_queue] )
        @consumers << Distribot.subscribe(message[:finished_queue]) do |task_info|
          handle_task_finished(message, task_info)
        end
#      else
#        puts "QUEUE DOESNT EXIST YET !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#      end
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
          # Distribot.broadcast! message[:cancel_consumer_queue], {
          #   type: 'cancel_consumer_queue',
          #   workflow_id: message[:workflow_id],
          #   phase: message[:phase],
          #   handler: message[:handler],
          #   task_queue: message[:task_queue]
          # }

# #byebug
           gonners = @consumers.select{|x| x.queue.name == message[:finished_queue]}
           @consumers -= gonners
# puts "________________ CANCEL(#{gonners.uniq{|x| x.queue.name }.map(&:queue).map(&:name)}) ______________________"
#pp canceling: gonners.uniq{|x| x.queue.name }.map(&:queue).map(&:name)
           gonners.uniq{|x| x.queue.name }.map(&:cancel)
        end
      end
    end
  end
end
