require 'spec_helper'

describe Distribot::PhaseStartedHandler do
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.flow.phase.started'
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
      @flow = Distribot::Flow.new(
        id: 1,
        name: 'test',
        phases: [{
          name: 'phase1',
          is_initial: true,
        }]
      )
      expect(Distribot::Flow).to receive(:find).with(1){ @flow }
      @phase = double('phase')
      expect(@phase).to receive(:handlers).at_least(1).times{ @handlers }
      expect(@flow).to receive(:phase).with('phase1'){ @phase }
    end
    context 'when this phase has' do
      context 'no handlers' do
        before do
          @handlers = [ ]
          expect(@phase).to receive(:name){ 'phase1' }
        end
        it 'considers this phase finished and publishes a message to that effect' do
          expect(Distribot).to receive(:publish!).with('distribot.flow.phase.finished', {
            flow_id: @flow.id,
            phase: 'phase1'
          })
          expect(Distribot).to receive(:subscribe)
          described_class.new.callback(flow_id: @flow.id, phase: 'phase1')
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
            expect(@worker).to receive(:init_handler).ordered.with(
              @flow,
              @phase,
              @handlers[0],
              '1.0'
            )
            expect(@worker).to receive(:init_handler).ordered.with(
              @flow,
              @phase,
              @handlers[1],
              '2.0'
            )
          end
          it 'jumpstarts each handler' do
            @worker.callback(flow_id: @flow.id, phase: 'phase1')
          end
        end
        context 'any of the handlers cannot find a suitable version' do
          before do
            expect(@worker).to receive(:best_version)
            expect(@worker).not_to receive(:init_handler)
          end
          it 'raises an exception' do
            expect{@worker.callback(flow_id: @flow.id, phase: 'phase1')}.to raise_error RuntimeError
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
            distribot.flow.handler.FooHandler.0.9.0.tasks
            distribot.flow.handler.FooHandler.1.0.0.tasks
            distribot.flow.handler.FooHandler.1.0.1.tasks
            distribot.flow.handler.FooHandler.2.0.0.tasks
            distribot.flow.handler.BarHandler.1.0.0.tasks
          )
        }
        connector
      end
      expect(Distribot).to receive(:subscribe)
      @worker = described_class.new
    end
    context 'when the handler version' do
      context 'is specified in the flow ' do
        before do
          @handler = Distribot::PhaseHandler.new(name: 'FooHandler', version: '~> 1.0')
        end
        it 'returns the highest available *matching* version for that handler' do
          expect(@worker.best_version(@handler)).to eq '1.0.1'
        end
      end
      context 'is not specified in the flow' do
        before do
          @handler = Distribot::PhaseHandler.new(name: 'FooHandler')
        end
        it 'returns the highest available version for that handler' do
          expect(@worker.best_version(@handler)).to eq '2.0.0'
        end
      end
    end
  end

  describe '#init_handler(flow, phase, handler, version)' do
    before do
      @flow = Distribot::Flow.new(id: 'xxx')
      @phase = Distribot::Phase.new(name: 'phase1')
      @handler = Distribot::PhaseHandler.new(name: 'FooHandler', version: '1.0')
      @version = '1.0'
      expect(Distribot).to receive(:subscribe)
      expect(Distribot).to receive(:publish!).with("distribot.flow.handler.#{@handler}.#{@version}.enumerate",
        flow_id: @flow.id,
        phase: @phase.name,
        task_queue: a_string_matching(/\.#{@handler}\.#{@version}\.tasks/),
        task_counter: a_string_matching(/\.#{@flow.id}\.#{@phase.name}\.#{@handler}\.finished/),
        finished_queue: 'distribot.flow.task.finished',
      )
    end
    it 'publishes a message for the handler with everything it needs to begin task enumeration' do
      described_class.new.init_handler(@flow, @phase, @handler, @version)
    end
  end
end
