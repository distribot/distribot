require 'spec_helper'

describe Distribot::PhaseStartedHandler do
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.phase.started'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(Distribot).to receive(:subscribe)
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback' do
    before do
      @workflow = Distribot::Workflow.new(
        id: 1,
        name: 'test',
        phases: [{
          name: 'phase1',
          is_initial: true,
        }]
      )
      expect(Distribot::Workflow).to receive(:find).with(1){ @workflow }
      @phase = double('phase')
      expect(@phase).to receive(:handlers).at_least(1).times{ @handlers }
      expect(@workflow).to receive(:phase).with('phase1'){ @phase }
    end
    context 'when this phase has' do
      context 'no handlers' do
        before do
          @handlers = [ ]
          expect(@phase).to receive(:name){ 'phase1' }
        end
        it 'considers this phase finished and publishes a message to that effect' do
          expect(Distribot).to receive(:publish!).with('distribot.workflow.phase.finished', {
            workflow_id: @workflow.id,
            phase: 'phase1'
          })
          expect(Distribot).to receive(:subscribe)
          described_class.new.callback(workflow_id: @workflow.id, phase: 'phase1')
        end
      end
      context 'some handlers' do
        before do
          @handlers = [
            Distribot::PhaseHandler.new( name: 'FooHandler' ),
            Distribot::PhaseHandler.new(
              name: 'BarHandler',
              version: '>= 1.0'
            )
          ]
          expect(Distribot).to receive(:subscribe)
          @worker = described_class.new
        end
        context 'and all the handlers have suitable version matches' do
          before do
            expect(@worker).to receive(:best_version).ordered.with(@handlers[0]){ '1.0' }
            expect(@worker).to receive(:best_version).ordered.with(@handlers[1]){ '2.0' }
            expect(@worker).to receive(:jumpstart_handler).ordered.with(
              @workflow,
              @phase,
              @handlers[0],
              '1.0'
            )
            expect(@worker).to receive(:jumpstart_handler).ordered.with(
              @workflow,
              @phase,
              @handlers[1],
              '2.0'
            )
          end
          it 'jumpstarts each handler' do
            @worker.callback(workflow_id: @workflow.id, phase: 'phase1')
          end
        end
      end
    end
  end

  describe '#best_version(handler)' do
    before do
      expect(Distribot).to receive(:connector) do
        connector = double('connector')
        expect(connector).to receive(:queues) {
          %w(
            distribot.workflow.handler.FooHandler.0.9.0.tasks
            distribot.workflow.handler.FooHandler.1.0.0.tasks
            distribot.workflow.handler.FooHandler.1.0.1.tasks
            distribot.workflow.handler.FooHandler.2.0.0.tasks
            distribot.workflow.handler.BarHandler.1.0.0.tasks
          )
        }
        connector
      end
      expect(Distribot).to receive(:subscribe)
      @worker = described_class.new
    end
    context 'when the handler version' do
      context 'is specified in the workflow ' do
        before do
          @handler = Distribot::PhaseHandler.new(name: 'FooHandler', version: '~> 1.0')
        end
        it 'returns the highest available *matching* version for that handler' do
          expect(@worker.best_version(@handler)).to eq '1.0.1'
        end
      end
      context 'is not specified in the workflow' do
        before do
          @handler = Distribot::PhaseHandler.new(name: 'FooHandler')
        end
        it 'returns the highest available version for that handler' do
          expect(@worker.best_version(@handler)).to eq '2.0.0'
        end
      end
    end
  end

  describe '#jumpstart_handler(workflow, phase, handler, version)' do
    before do
      @workflow = Distribot::Workflow.new(id: 'xxx')
      @phase = Distribot::Phase.new(name: 'phase1')
      @handler = Distribot::PhaseHandler.new(name: 'FooHandler', version: '1.0')
      @version = '1.0'
      expect(Distribot).to receive(:subscribe)
      expect(Distribot).to receive(:publish!).with("distribot.workflow.handler.#{@handler}.#{@version}.enumerate",
        workflow_id: @workflow.id,
        phase: @phase.name,
        task_queue: a_string_matching(/\.#{@handler}\.#{@version}\.tasks/),
        task_counter: a_string_matching(/\.#{@workflow.id}\.#{@phase.name}\.#{@handler}\.finished/),
        finished_queue: 'distribot.workflow.task.finished',
      )
    end
    it 'publishes a message for the handler with everything it needs to begin task enumeration' do
      described_class.new.jumpstart_handler(@workflow, @phase, @handler, @version)
    end
  end
end
