
module Distribot
  module Worker
    def self.included(klass)

      klass.class_eval do
        def self.enumerate_with(callback)
          @@enumerator = callback
        end
        def self.enumerator
          @@enumerator
        end
        def self.process_tasks_with(callback)
          @@processor = callback
        end
        def self.processor
          @@processor
        end
        def self.enumeration_queue
          "distribot.workflow.handler.#{self}.enumerate"
        end
        def self.process_queue
          "distribot.workflow.handler.#{self}.process"
        end

        def initialize
          semaphore = Mutex.new
          @task_consumers ||= [ ]
          Distribot.subscribe( self.class.enumeration_queue ) do |message|
            context = OpenStruct.new(message)
            self.send(self.class.enumerator, context) do |tasks|
              task_queue = message[:task_queue]
              Distribot.redis.incrby task_queue, tasks.count
              tasks.each do |task|
                Distribot.publish! task_queue, task
              end
            end

            Distribot.publish! 'distribot.workflow.handler.enumerated', {
              workflow_id: message[:workflow_id],
              phase: message[:phase],
              task_queue: message[:task_queue],
              finished_queue: message[:finished_queue],
              handler: self.class.to_s
            }
            nil
          end


          Distribot.subscribe_multi( 'distribot.cancel.consumer' ) do |cancel_message|
            gonners = @task_consumers.select{|x| x && (x.queue.name == cancel_message[:task_queue])}
            unless gonners.empty?
              semaphore.synchronize do
                gonners.each do |gonner|
                  gonner.cancel
                end
                @task_consumers -= gonners
              end
            end
            nil
          end

          Distribot.subscribe_multi( self.class.process_queue ) do |message|
            not_already_subscribed = semaphore.synchronize{ @task_consumers.select{|x| x && (x.queue.name == message[:task_queue])}.empty? }
            if not_already_subscribed
              consumer = Distribot.subscribe(message[:task_queue]) do |task|
                context = OpenStruct.new(
                  workflow_id: message[:workflow_id],
                  phase: message[:phase],
                )
                self.send(self.class.processor, context, task)
                Distribot.publish! message[:finished_queue], {
                  workflow_id: message[:workflow_id],
                  phase: message[:phase],
                  handler: self.class
                }
                nil
              end
              semaphore.synchronize do
                @task_consumers << consumer
              end
            end
            nil
          end

        end

      end
    end

  end
end
