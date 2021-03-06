require 'spec_helper'

describe Distribot::Worker do
  describe '.included(klass)' do
    before do
      @klass = "Foo#{SecureRandom.hex(10)}"
      eval <<-EOF
class #{@klass}
  include Distribot::Worker
  version '1.1.1'
end
      EOF
    end
    it 'adds an enumerate_with(:callback) method' do
      expect(Kernel.const_get(@klass)).to respond_to(:enumerate_with)
    end
    it 'adds an enumerator accessor' do
      Kernel.const_get(@klass).send :enumerate_with, 'foo'
      expect(Kernel.const_get(@klass).send :enumerator).to eq 'foo'
    end
    it 'adds a process_tasks_with(:callback) method' do
      expect(Kernel.const_get(@klass)).to respond_to(:process_tasks_with)
    end
    it 'adds a processor accessor' do
      Kernel.const_get(@klass).send :process_tasks_with, 'foo'
      expect(Kernel.const_get(@klass).send :processor).to eq 'foo'
    end
    it 'adds an enumeration_queue accessor' do
      @klass_ref = Kernel.const_get(@klass)
      expect(@klass_ref.send :enumeration_queue).to eq "distribot.flow.handler.#{@klass}.#{@klass_ref.version}.enumerate"
    end
    it 'adds a task_queue accessor' do
      @klass_ref = Kernel.const_get(@klass)
      expect(@klass_ref.send :task_queue).to eq "distribot.flow.handler.#{@klass}.#{@klass_ref.version}.tasks"
    end
  end

  describe '#run' do
    before :each do
      @klass = "FooWorker#{SecureRandom.hex(8)}"
      eval <<-EOF
class #{@klass}
  include Distribot::Worker
  enumerate_with :enumerate
  process_tasks_with :process

  def enumerate(context)
    logger.info "HELLO FROM #{self}!"
    jobs = [{id: 'job1'}, {id: 'job2'}]
    return jobs
  end

  def process(context, job)
    job
  end
end
      EOF
      @class_ref = Kernel.const_get(@klass)
    end
    it 'prepares the worker' do
      worker = @class_ref.new
      expect(worker).to receive(:prepare_for_enumeration)
      expect(worker).to receive(:subscribe_to_task_queue)
      worker.run
    end
    describe '#prepare_for_enumeration' do
      before do
        @worker = @class_ref.new
        @flow = Distribot::Flow.new(id: 'xxx', phases: [{name: 'start', is_initial: true}])
        expect(Concurrent::FixedThreadPool).to receive(:new) do
          pool = double('pool')
          expect(pool).to receive(:post) do |&block|
            block.call
          end
          pool
        end
      end
      context 'when enumeration' do
        context 'succeeds' do
          it 'goes smoothly' do
            message = {
              flow_id: @flow.id,
              phase: 'phase1',
              task_queue: 'task-queue',
              finished_queue: 'finished-queue',
              handler: @klass
            }
            expect(Distribot).to receive(:subscribe).with(@class_ref.enumeration_queue, solo: true) do |&block|
              @callback = block
            end

            expect(@worker).to receive(:enumerate_tasks).with(message)
            expect(@worker).to receive(:announce_tasks).with(anything, message, anything)

            # Finally:
            @worker.prepare_for_enumeration

            @callback.call(message)
          end
        end
        context 'raises an exception' do
          before do
            expect(@worker).to receive(:enumerate_tasks){ raise "Test Error" }
            expect(Distribot).to receive(:subscribe).with(@class_ref.enumeration_queue, solo: true) do |&block|
              @callback = block
            end
            expect(@worker).to receive(:warn)
          end
          it 'logs the error and re-raises the exception' do
            @worker.prepare_for_enumeration
            expect{@callback.call({})}.to raise_error StandardError
          end
        end
      end
    end
    describe '#enumerate_tasks(message)' do
      before do
        @klass_ref = Kernel.const_get(@klass)
        @worker = @klass_ref.new
      end
      context 'when the flow' do
        before do
          @flow = double('flow')
          expect(Distribot::Flow).to receive(:find).with( 'xxx' ){ @flow }
        end
        context 'is canceled' do
          before do
            expect(@flow).to receive(:canceled?){ true }
          end
          it 'raises an error' do
            expect(@worker).to receive(:warn)
            expect{@worker.enumerate_tasks(flow_id: 'xxx')}.to raise_error Distribot::FlowCanceledError
          end
        end
        context 'is not canceled' do
          before do
            expect(@flow).to receive(:canceled?){ false }
          end
          it 'calls the task enumerator method, then accounts for the tasks it returns' do

            # Finally:
            @worker.enumerate_tasks(flow_id: 'xxx', task_counter: 'task.counter' )
          end
        end
      end
    end
    describe '#announce_tasks(context, message, tasks)' do
      before do
        @flow = Distribot::Flow.new(id: 'xxx')
        @message = {
          flow_id: @flow.id,
          phase: 'phase1',
          task_queue: 'task-queue',
          finished_queue: 'finished-queue',
          task_counter: 'task-counter',
          handler: @klass
        }
        @tasks = [
          {id: 1},
          {id: 2}
        ]
        @klass_ref = Kernel.const_get(@klass)
        @worker = @klass_ref.new
        redis = double('redis')
        expect(redis).to receive(:incrby).with(@message[:task_counter], @tasks.count)
        expect(redis).to receive(:incrby).with("#{@message[:task_counter]}.total", @tasks.count)
        expect(Distribot).to receive(:redis).exactly(2).times{ redis }
        expect(Distribot).to receive(:publish!).with(@message[:task_queue], hash_including({})).exactly(@tasks.count).times
      end
      it 'announces the new tasks on the task queue' do
        context = OpenStruct.new(@message)
        @worker.send(
          :announce_tasks,
          context,
          @message,
          @tasks
        )
      end
    end
    describe '#subscribe_to_task_queue' do
      before do
        @pool = double('pool')
        expect(Concurrent::FixedThreadPool).to receive(:new) do
          @pool
        end
      end
      it 'subscribes to the task queue for this $flow.$phase.$handler so it can consume them, and stores the consumer for cancelation later' do
        worker = @class_ref.new
        expect(Distribot).to receive(:subscribe).with(@class_ref.task_queue, reenqueue_on_failure: true, solo: true) do |&block|
          'fake-consumer'
        end
        worker.subscribe_to_task_queue
      end
      context 'when it receives a task to work on' do
        before do
          expect(Distribot).to receive(:subscribe).with(@class_ref.task_queue, reenqueue_on_failure: true, solo: true) do |&block|
            @callback = block
          end
          expect(@pool).to receive(:post) do |&block|
            block.call
          end
        end
        context 'and processing that task' do
          context 'succeeds' do
            it 'calls #process_single_task(contxt, task)' do
              task = {some_task_thing: SecureRandom.uuid}
              worker = @class_ref.new
              expect(worker).to receive(:process_single_task).with(anything, task)
              worker.subscribe_to_task_queue
              @callback.call(task)
            end
          end
          context 'raises an exception' do
            it 'logs the error and re-raises the exception' do
              task = {some_task_thing: SecureRandom.uuid}
              worker = @class_ref.new
              expect(worker).to receive(:process_single_task){ raise "Test Error" }
              worker.subscribe_to_task_queue
              expect(worker).to receive(:warn)
              expect{@callback.call(task)}.to raise_error StandardError
            end
          end
        end
      end
    end
    describe '#process_single_task(context, task)' do
      before do
        @klass_ref = Kernel.const_get(@klass)
        @worker = @klass_ref.new
      end
      context 'when the flow' do
        before do
          @flow = double('flow')
          expect(Distribot::Flow).to receive(:find).with( 'xxx' ){ @flow }
          @context = OpenStruct.new(
            flow_id: 'xxx',
            finished_queue: 'finished.queue',
            phase: 'the-phase',
          )
          @task = { }
        end
        context 'is canceled' do
          before do
            expect(@flow).to receive(:canceled?){ true }
          end
          it 'raises an exception' do
            expect{@worker.process_single_task(@context, @task)}.to raise_error Distribot::FlowCanceledError
          end
        end
        context 'is paused' do
          before do
            expect(@flow).to receive(:paused?){ true }
            expect(@flow).to receive(:canceled?){ false }
          end
          it 'raises an exception' do
            expect{@worker.process_single_task(@context, @task)}.to raise_error Distribot::FlowPausedError
          end
        end
        context 'is running' do
          before do
            expect(@flow).to receive(:paused?){ false }
            expect(@flow).to receive(:canceled?){ false }
            expect(Distribot).to receive(:publish!).with(@context.finished_queue, {
              flow_id: 'xxx',
              phase: 'the-phase',
              handler: @klass
            })
            redis = double('redis')
            expect(redis).to receive(:decr).with(
              "distribot.flow.#{@context.flow_id}.#{@context.phase}.#{@klass}.finished"
            )
            expect(Distribot).to receive(:redis){ redis }
          end
          it 'calls the worker\'s processor callback, then announces that the task has been completed' do
            @worker.process_single_task(@context, @task)
          end
        end
      end
    end
  end
end
