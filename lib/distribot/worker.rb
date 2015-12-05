
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

        def initialize
          @semaphore = Mutex.new
          self.task_consumers = [ ]
        end

        def run
          self.prepare_for_enumeration
          self.prepare_for_consumer_cancelation
          self.prepare_for_task_processing
          self
        end

        def prepare_for_enumeration
          Distribot.subscribe( self.class.enumeration_queue ) do |message|
            enumerate_tasks(message)
          end
        end

        def prepare_for_consumer_cancelation
          Distribot.subscribe_multi( 'distribot.cancel.consumer' ) do |cancel_message|
            self.cancel_consumers_for(cancel_message[:task_queue])
          end
        end

        def prepare_for_task_processing
          Distribot.subscribe_multi( self.class.process_queue ) do |message|
            unless self.currently_subscribed_to_task_queue?(message[:task_queue])
              self.subscribe_to_task_queue(message)
            end
          end
        end

        def subscribe_to_task_queue(message)
          consumer = Distribot.subscribe(message[:task_queue]) do |task|
            context = OpenStruct.new(
              workflow_id: message[:workflow_id],
              phase: message[:phase],
              finished_queue: message[:finished_queue],
            )
            self.process_single_task(context, task)
          end
          @semaphore.synchronize do
            self.task_consumers << consumer
          end
        end

        def process_single_task(context, task)
          # Your code is called right here:
          self.send(self.class.processor, context, task)

          # Now tell the world we finished this task:
          Distribot.publish! context.finished_queue, {
            workflow_id: context.workflow_id,
            phase: context.phase,
            handler: self.class
          }
        end

        def enumerate_tasks(message)
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
        end

        def cancel_consumers_for(task_queue)
          gonners = self.consumers_of_queue(task_queue)
          unless gonners.empty?
            @semaphore.synchronize do
              gonners.each do |gonner|
                gonner.cancel
              end
              @task_consumers -= gonners
            end
          end
        end

        def currently_subscribed_to_task_queue?(task_queue)
          ! self.consumers_of_queue(task_queue).empty?
        end

        def consumers_of_queue(task_queue)
          @semaphore.synchronize do
            self.task_consumers
              .select{|x| x && (x.queue.name == task_queue)}
          end
        end
      end
    end

  end
end
