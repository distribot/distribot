require 'spec_helper'

describe Distribot::Worker do
  describe '.included(klass)' do
    before do
      @klass = "Foo#{SecureRandom.hex(10)}"
      eval <<-EOF
class #{@klass}
  include Distribot::Worker
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
      expect(Kernel.const_get(@klass).send :enumeration_queue).to eq "distribot.workflow.handler.#{@klass}.enumerate"
    end
    it 'adds a process_queue accessor' do
      expect(Kernel.const_get(@klass).send :process_queue).to eq "distribot.workflow.handler.#{@klass}.process"
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

  def enumerate(context, &callback)
    jobs = ['job1', 'job2']
    callback.call( jobs )
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
      expect(worker).to receive(:prepare_for_consumer_cancelation)
      expect(worker).to receive(:prepare_for_task_processing)
      worker.run
    end
    describe '#currently_subscribed_to_task_queue?(task_queue)' do
      before do
        @worker = @class_ref.new

        consumer = double('consumer')
        expect(consumer).to receive(:queue) do
          queue = double('queue')
          expect(queue).to receive(:name){ 'subscribed-task-queue' }
          queue
        end

        @worker.task_consumers = [consumer]
      end
      context 'when it is subscribed' do
        it 'returns true' do
          expect(@worker.currently_subscribed_to_task_queue?('subscribed-task-queue')).to be_truthy
        end
      end
      context 'when it is not subscribed' do
        it 'returns false' do
          expect(@worker.currently_subscribed_to_task_queue?('task-queue-not-subscribed-to')).to be_falsey
        end
      end
    end
    describe '#prepare_for_enumeration' do
      before do
        @worker = @class_ref.new
      end
      it 'prepares for enumeration' do
        message = {
          workflow_id: 'workflow-id',
          phase: 'phase1',
          task_queue: 'task-queue',
          finished_queue: 'finished-queue',
          handler: @klass
        }
        expect(Distribot).to receive(:subscribe).with(@class_ref.enumeration_queue) do |&block|
          @callback = block
        end

        expect(@worker).to receive(:enumerate_tasks).with(message).and_call_original
        expect(Distribot).to receive(:publish!).ordered.with('task-queue', 'job1')
        expect(Distribot).to receive(:publish!).ordered.with('task-queue', 'job2')
        expect(Distribot).to receive(:publish!).ordered.with('distribot.workflow.handler.enumerated', message)

        # Finally:
        @worker.prepare_for_enumeration

        @callback.call(message)
      end
    end
    describe '#prepare_for_consumer_cancelation' do
      it 'subscribes to the consumer-canceling fanout exchange with the correct callback' do
        worker = @class_ref.new
        message = {task_queue: 'the-task-queue-for-this-handler'}
        expect(Distribot).to receive(:subscribe_multi).with('distribot.cancel.consumer') do |&block|
          @callback = block
        end
        expect(worker).to receive(:cancel_consumers_for).with(message[:task_queue])

        # Finally:
        worker.prepare_for_consumer_cancelation
        @callback.call(message)
      end
    end
    describe '#cancel_consumers_for(task_queue)' do
      it 'cancels consumers for the task_queue provided by name' do
        task_queue = 'the-task-queue-for-this-handler'
        worker = @class_ref.new

        expect(worker).to receive(:consumers_of_queue).with(task_queue) do
          consumer = double('consumer')
          expect(consumer).to receive(:cancel)
          [ consumer ]
        end

        # Finally:
        worker.cancel_consumers_for(task_queue)
      end
    end
    describe '#prepare_for_task_processing' do
      context 'when the worker' do
        before do
          @message = {
            workflow_id: SecureRandom.uuid,
            phase: 'phase1',
            handler: @klass,
            task_queue: 'the-task-queue',
            finished_queue: 'the-finished-queue'
          }
          @worker = @class_ref.new

          expect(Distribot).to receive(:subscribe_multi).with(@class_ref.process_queue) do |&block|
            @callback = block
          end
        end
        context 'is already subscribed to the task queue' do
          before do
            expect(@worker).to receive(:currently_subscribed_to_task_queue?).with(@message[:task_queue]){ true }
          end
          it 'does not re-suscribe' do
            expect(@worker).not_to receive(:subscribe_to_task_queue)

            # Finally:
            @worker.prepare_for_task_processing
            @callback.call(@message)
          end
        end
        context 'is not yet subscribed to the task queue' do
          before do
            expect(@worker).to receive(:currently_subscribed_to_task_queue?).with(@message[:task_queue]){ false }
          end
          it 'subscribes to the task_queue with the correct callback' do
            expect(@worker).to receive(:subscribe_to_task_queue).with(@message)

            # Finally:
            @worker.prepare_for_task_processing
            @callback.call(@message)
          end
        end
      end
    end
    describe '#subscribe_to_task_queue(message)' do
      before do
        @message = {
          task_queue: 'the-task-queue',
          workflow_id: SecureRandom.uuid,
          phase: 'phase1',
          finished_queue: 'the-finished-queue'
        }
      end
      it 'subscribes to the task queue for this $workflow.$phase.$handler so it can consume them, and stores the consumer for cancelation later' do
        worker = @class_ref.new
        expect(Distribot).to receive(:subscribe).with(@message[:task_queue]) do |&block|
          'fake-consumer'
        end
        worker.subscribe_to_task_queue(@message)
        expect(worker.task_consumers).to include 'fake-consumer'
      end
      context 'when it receives a task to work on' do
        before do
          expect(Distribot).to receive(:subscribe).with(@message[:task_queue]) do |&block|
            @callback = block
          end
        end
        it 'calls #process_single_task(contxt, task)' do
          task = {some_task_thing: SecureRandom.uuid}
          worker = @class_ref.new
          expect(worker).to receive(:process_single_task).with(anything, task)
          worker.subscribe_to_task_queue(@message)
          @callback.call(task)
        end
      end
    end
    describe '#process_single_task(context, task)' do
      it 'calls the worker\'s processor callback, then announces that the task has been completed' do
        worker = @class_ref.new
        task = {foo: SecureRandom.uuid}
        context = OpenStruct.new(
          workflow_id: SecureRandom.uuid,
          phase: 'phase1',
          finished_queue: 'the-finished-queue'
        )
        expect(worker).to receive(@class_ref.processor).with(context, task)
        expect(Distribot).to receive(:publish!).with(context.finished_queue, {
          workflow_id: context.workflow_id,
          phase: context.phase,
          handler: @class_ref
        })

        # Finally:
        worker.process_single_task(context, task)
      end
    end
  end
end
