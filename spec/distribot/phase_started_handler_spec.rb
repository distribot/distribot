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
    context 'when this phase has' do
      context 'no handlers' do
        before do
          @workflow = Distribot::Workflow.new(
            id: 1,
            name: 'test',
            phases: [{
              name: 'phase1',
              is_initial: true,
              handlers: [ ]
            }]
          )
          expect(Distribot::Workflow).to receive(:find).with(1){ @workflow }
        end
        it 'publishes a message to the distribot.workflow.phase.finished queue' do
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
          @workflow = Distribot::Workflow.new(
            id: SecureRandom.uuid,
            name: 'test',
            phases: [{
              name: 'phase1',
              is_initial: true,
              handlers: [
                {
                  name: 'FooHandler',
                  version: '1.0.1'
                }
              ]
            }]
          )
          expect(Distribot::Workflow).to receive(:find).with(@workflow.id){ @workflow }
          expect(Distribot).to receive(:connector) do
            connector = double('connector')
            expect(connector).to receive(:queues) do
              [
                'distribot.workflow.handler.FooHandler.1.0.1.enumerate',
                'distribot.workflow.handler.FooHandler.2.0.1.enumerate',
                'distribot.workflow.handler.FooHandler.1.0.1.tasks',
                'distribot.workflow.handler.FooHandler.2.0.1.tasks'
              ]
            end
            connector
          end
          enumerate_queue = 'distribot.workflow.handler.FooHandler.1.0.1.enumerate'
          process_queue = 'distribot.workflow.handler.FooHandler1.0.1.process'
          task_queue = 'distribot.workflow.handler.FooHandler.1.0.1.tasks'
          finished_queue = 'distribot.workflow.task.finished'
          task_counter = 'distribot.workflow.' + @workflow.id + '.phase1.FooHandler.finished'

          expect(Distribot).to receive(:publish!).with(enumerate_queue, {
            task_queue: task_queue,
            workflow_id: @workflow.id,
            phase: 'phase1',
            finished_queue: finished_queue,
            task_counter: task_counter
          })
          expect(Distribot).to receive(:subscribe)
        end
        it 'publishes and broadcasts to the correct queues with the correct params' do
          described_class.new.callback(workflow_id: @workflow.id, phase: 'phase1')
        end
      end
    end
  end
end
