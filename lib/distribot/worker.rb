
module Distribot
  class WorkflowCanceledError < StandardError; end
  class WorkflowPausedError < StandardError; end
  module Worker
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      class << self
        attr_accessor :version, :enumerator, :process_tasks_with, :processor
      end

      attr_reader :processor, :enumerator

      def enumerate_with(callback)
        @enumerator = callback
      end

      def process_tasks_with(callback)
        @processor = callback
      end

      # Does both setting/getting:
      def version(val = nil)
        @version ||= '0.0.0'
        @version = val unless val.nil?
        @version
      end

      def enumeration_queue
        self.version ||= '0.0.0'
        "distribot.workflow.handler.#{self}.#{self.version}.enumerate"
      end

      def task_queue
        self.version ||= '0.0.0'
        "distribot.workflow.handler.#{self}.#{self.version}.tasks"
      end
    end

    attr_accessor :task_consumers

    def run
      prepare_for_enumeration
      subscribe_to_task_queue
      self
    end

    def logger
      Distribot.logger
    end

    def prepare_for_enumeration
      logger.tagged("handler:#{self.class}") do
        pool = Concurrent::FixedThreadPool.new(5)
        Distribot.subscribe(self.class.enumeration_queue, solo: true) do |message|
          pool.post do
            logger.tagged(message.map { |k, v| [k, v].join(':') }) do
              context = OpenStruct.new(message)
              trycatch do
                tasks = enumerate_tasks(message)
                announce_tasks(context, message, tasks)
              end
            end
          end
        end
      end
    end

    def subscribe_to_task_queue
      logger.tagged("handler:#{self.class}") do
        subscribe_args = { reenqueue_on_failure: true, solo: true }
        pool = Concurrent::FixedThreadPool.new(500)
        Distribot.subscribe(self.class.task_queue, subscribe_args) do |task|
          pool.post do
            logger_tags = task.map { |k, v| [k, v].join(':') }
            logger.tagged(logger_tags) do
              handle_task_execution(task)
            end
          end
        end
      end
    end

    def handle_task_execution(task)
      context = OpenStruct.new(
        workflow_id: task[:workflow_id],
        phase: task[:phase],
        finished_queue: 'distribot.workflow.task.finished'
      )
      trycatch do
        process_single_task(context, task)
      end
    end

    def process_single_task(context, task)
      inspect_task!(context)
      # Your code is called right here:
      send(self.class.processor, context, task)
      task_counter_key = "distribot.workflow.#{context.workflow_id}.#{context.phase}.#{self.class}.finished"
      Distribot.redis.decr(task_counter_key)
      publish_args = {
        workflow_id: context.workflow_id,
        phase: context.phase,
        handler: self.class.to_s
      }
      Distribot.publish!(context.finished_queue, publish_args)
    end

    def enumerate_tasks(message)
      trycatch do
        context = OpenStruct.new(message)
        workflow = Distribot::Workflow.find(context.workflow_id)
        fail WorkflowCanceledError if workflow.canceled?
        send(self.class.enumerator, context)
      end
    end

    private

    def announce_tasks(context, message, tasks)
      task_counter = message[:task_counter]
      Distribot.redis.incrby task_counter, tasks.count
      Distribot.redis.incrby "#{task_counter}.total", tasks.count
      tasks.each do |task|
        task.merge!(workflow_id: context.workflow_id, phase: context.phase)
        Distribot.publish! message[:task_queue], task
      end
    end

    def inspect_task!(context)
      workflow = Distribot::Workflow.find(context.workflow_id)
      fail WorkflowCanceledError if workflow.canceled?
      fail WorkflowPausedError if workflow.paused?
    end

    def trycatch(&block)
      # Put the try/catch logic here to reduce boilerplate code:
      block.call
    rescue StandardError => e
      logger.error "ERROR: #{e} --- #{e.backtrace.join("\n")}"
      warn "ERROR: #{e} --- #{e.backtrace.join("\n")}"
      raise e
    end
  end
end
