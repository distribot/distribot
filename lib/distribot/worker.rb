
module Distribot
  module Worker

    class WorkflowCanceledError < StandardError; end
    class WorkflowPausedError < StandardError; end

    def self.included(klass)

      klass.class_eval do
        @@version ||= '0.0.0'
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

        # Does both setting/getting:
        def self.version(val=nil)
          unless val.nil?
            @@version = val
          end
          @@version
        end

        def self.enumeration_queue
#          "distribot.workflow.handler.#{self}.#{version}.enumerate"
          "distribot.workflow.handler.#{self}.enumerate"
        end
        def self.process_queue
#          "distribot.workflow.handler.#{self}.#{version}.process"
          "distribot.workflow.handler.#{self}.process"
        end
        attr_accessor :task_consumers

        def run
          self.prepare_for_enumeration
          self.subscribe_to_task_queue
          self
        end

        def logger
          Distribot.logger
        end

        def prepare_for_enumeration
          logger.tagged("#{self.class}") do
            Distribot.subscribe( self.class.enumeration_queue ) do |message|
              logger.tagged("handler:#{self.class}", "phase:#{message[:phase]}", "workflow_id:#{message[:workflow_id]}") do
                begin
                  enumerate_tasks(message)
                rescue StandardError => e
                  logger.error "ERROR: #{e} --- #{e.backtrace.join("\n")}"
                  raise e
                end
              end
            end
          end
        end

        def self.task_queue
          "distribot.workflow.handler.#{self}.tasks"
        end

        def subscribe_to_task_queue
          logger.tagged("#{self.class}") do
            Distribot.subscribe(self.class.task_queue, reenqueue_on_failure: true) do |task|
              logger.tagged("handler:#{self.class}", "phase:#{task[:phase]}", "workflow_id:#{task[:workflow_id]}") do
                context = OpenStruct.new(
                  workflow_id: task[:workflow_id],
                  phase: task[:phase],
                  finished_queue: 'distribot.workflow.task.finished',
                )
                begin
                  self.process_single_task(context, task)
                rescue StandardError => e
                  logger.error "ERROR: #{e} --- #{e.backtrace.join("\n")}"
                  raise e
                end
              end
            end
          end
        end

        def process_single_task(context, task)
          workflow = Distribot::Workflow.find( context.workflow_id )
          if workflow.canceled?
            raise WorkflowCanceledError.new
          elsif workflow.paused?
            raise WorkflowPausedError.new
          end

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
          workflow = Distribot::Workflow.find( context.workflow_id )
          raise WorkflowCanceledError.new if workflow.canceled?
          self.send(self.class.enumerator, context) do |tasks|
            task_counter = message[:task_counter]
            Distribot.redis.incrby task_counter, tasks.count
            Distribot.redis.incrby "#{task_counter}.total", tasks.count
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
