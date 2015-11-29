
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
          Distribot.subscribe( self.class.enumeration_queue ) do |message|
            context = OpenStruct.new(message)
            self.send(self.class.enumerator, context) do |tasks|
              task_queue = message[:task_queue]
              Distribot.redis.incrby task_queue, tasks.count
              tasks.each do |task|
pp "TASK(#{task})"
                Distribot.publish! task_queue, task
              end
            end
          end

          Distribot.subscribe_multi( self.class.process_queue ) do |message|
pp process_queue: self.class.process_queue, message: message
            Distribot.subscribe(message[:task_queue]) do |task|
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
            end
          end
        end

      end
    end

  end
end
