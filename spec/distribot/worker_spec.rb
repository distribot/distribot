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
    logger.info "HELLO FROM #{self}!"
    jobs = [{id: 'job1'}, {id: 'job2'}]
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
      expect(worker).to receive(:subscribe_to_task_queue)
      worker.run
    end
    describe '#prepare_for_enumeration' do
      before do
        @worker = @class_ref.new
        @workflow = Distribot::Workflow.create!(phases: [{name: 'start', is_initial: true}])
      end
      it 'prepares for enumeration' do
        message = {
          workflow_id: @workflow.id,
          phase: 'phase1',
          task_queue: 'task-queue',
          finished_queue: 'finished-queue',
          handler: @klass
        }
        expect(Distribot).to receive(:subscribe).with(@class_ref.enumeration_queue) do |&block|
          @callback = block
        end

        expect(@worker).to receive(:enumerate_tasks).with(message).and_call_original
        expect(Distribot).to receive(:publish!).ordered.with('task-queue', hash_including(id: 'job1'))
        expect(Distribot).to receive(:publish!).ordered.with('task-queue', hash_including(id: 'job2'))

        # Finally:
        @worker.prepare_for_enumeration

        @callback.call(message)
      end
    end
    describe '#subscribe_to_task_queue' do
      it 'subscribes to the task queue for this $workflow.$phase.$handler so it can consume them, and stores the consumer for cancelation later' do
        worker = @class_ref.new
        expect(Distribot).to receive(:subscribe).with(@class_ref.task_queue, reenqueue_on_failure: true) do |&block|
          'fake-consumer'
        end
        worker.subscribe_to_task_queue
      end
      context 'when it receives a task to work on' do
        before do
          expect(Distribot).to receive(:subscribe).with(@class_ref.task_queue, reenqueue_on_failure: true) do |&block|
            @callback = block
          end
        end
        it 'calls #process_single_task(contxt, task)' do
          task = {some_task_thing: SecureRandom.uuid}
          worker = @class_ref.new
          expect(worker).to receive(:process_single_task).with(anything, task)
          worker.subscribe_to_task_queue
          @callback.call(task)
        end
      end
    end
    describe '#process_single_task(context, task)' do
      it 'calls the worker\'s processor callback, then announces that the task has been completed' do
        worker = @class_ref.new
        @workflow = Distribot::Workflow.create!(phases: [{name: 'start', is_initial: true}])
        task = {foo: SecureRandom.uuid}
        context = OpenStruct.new(
          workflow_id: @workflow.id,
          phase: 'phase1',
          finished_queue: 'the-finished-queue'
        )
        expect(worker).to receive(@class_ref.processor).with(context, task)
        expect(Distribot).to receive(:publish!).with(context.finished_queue, {
          workflow_id: context.workflow_id,
          phase: context.phase,
          handler: @class_ref.to_s
        })

        # Finally:
        worker.process_single_task(context, task)
      end
    end
  end
end
