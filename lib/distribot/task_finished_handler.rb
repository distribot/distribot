
module Distribot

  class TaskFinishedHandler
    attr_accessor :foo
    include Distribot::Handler
    subscribe_to 'distribot.workflow.handler.enumerated', handler: :callback

    def callback(message)
      self.foo ||= Distribot.subscribe('distribot.workflow.task.finished') do |task_info|
puts "GOT MESSAGE on 'distribot.workflow.task.finished' /////////////////////"
        handle_task_finished(message, task_info)
      end
    end

    def handle_task_finished(message, task_info)
      task_counter = "distribot.workflow.#{message[:workflow_id]}.#{message[:phase]}.#{message[:handler]}.finished"
puts "task_counter(#{task_counter})"
      current_value = Distribot.redis.get(task_counter)
puts "CURRENT_VALUE: '#{current_value.nil? ? 'nil' : current_value}'"
      unless current_value.nil?
        new_value = Distribot.redis.decr task_counter
puts "%%%%%%%% current_value.nil?(#{current_value.nil?}): #{task_counter} '#{current_value}' ----> #{new_value}"
        if new_value.to_i <= 0
          Distribot.redis.del(task_counter)
puts "********** FINISHED A HANDLER: #{message[:handler]} **********"
          sleep 1
          Distribot.publish! 'distribot.workflow.handler.finished', {
            workflow_id: message[:workflow_id],
            phase: message[:phase],
            handler: message[:handler],
            task_queue: message[:task_queue]
          }
#          Distribot.cancel_consumers_for(message[:finished_queue], close: true)
        end
      end
    end
  end
end
