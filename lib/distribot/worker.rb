
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
            self.send self.class.enumerator, message do |tasks|
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
              self.send(self.class.processor, task)
              Distribot.publish! message[:finished_queue], {yay: Time.now.to_f}
            end
          end
        end

      end
    end

  end
end
