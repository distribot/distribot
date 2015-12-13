
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
        attr_accessor :task_consumers

        def run
          self.prepare_for_enumeration
          self.subscribe_to_task_queue
          self
        end

        def prepare_for_enumeration
          Distribot.subscribe( self.class.enumeration_queue ) do |message|
            enumerate_tasks(message)
          end
        end

        def self.task_queue
          "distribot.workflow.#{self.class}.tasks"
        end

        def subscribe_to_task_queue
          Distribot.subscribe(self.class.task_queue, reenqueue_on_failure: true) do |task|
            context = OpenStruct.new(
              workflow_id: task[:workflow_id],
              phase: task[:phase],
              finished_queue: 'distribot.workflow.task.finished',
            )
            self.process_single_task(context, task)
          end
        end

        def process_single_task(context, task)
          # Your code is called right here:
          self.send(self.class.processor, context, task)

          # Now tell the world we finished this task:
          Distribot.publish! context.finished_queue, {
            workflow_id: context.workflow_id,
            phase: context.phase,
            handler: self.class.to_s
          }
        end

        def enumerate_tasks(message)
          context = OpenStruct.new(message)
          self.send(self.class.enumerator, context) do |tasks|
            task_counter = message[:task_counter]
            Distribot.redis.incrby task_counter, tasks.count
            tasks.each do |task|
              Distribot.publish! message[:task_queue], task.merge(
                workflow_id: context.workflow_id,
                phase: context.phase
              )
            end
          end
        end
      end
    end

  end
end
