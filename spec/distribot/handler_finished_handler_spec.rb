require 'spec_helper'

describe Distribot::HandlerFinishedHandler do
  before do
    Distribot.stub(:subscribe)
  end
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.flow.handler.finished'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback(message)' do
    before do
      @message = {
        task_queue: 'task-queue',
        flow_id: 'flow-id',
        phase: 'phase1'
      }
      @handler = described_class.new
    end
    context 'when all the handler\'s tasks' do
      context 'are complete' do
        before do
          expect(Distribot::Flow).to receive(:find).with(@message[:flow_id]) do
            Distribot::Flow.new(id: @message[:flow_id], phases: [{name:'phase1', handlers: []}])
          end
          expect(@handler).to receive(:all_phase_handler_tasks_are_complete?){ true }
        end
        it 'announces that this phase has completed and that everyone should stop consuming its task.finished queue' do
          # Describe what 'nothing' looks like:
          expect(Distribot).to receive(:publish!).with('distribot.flow.phase.finished', {
            flow_id: @message[:flow_id],
            phase: 'phase1'
          })

          # Finally:
          @handler.callback(@message)
        end
      end
      context 'are not yet complete' do
        before do
          expect(Distribot::Flow).to receive(:find).with(@message[:flow_id]) do
            Distribot::Flow.new(id: @message[:flow_id], phases: [{name:'phase1', handlers: []}])
          end
          expect(@handler).to receive(:all_phase_handler_tasks_are_complete?){ false }
        end
        it 'does nothing' do
          # Describe what 'nothing' looks like:
          expect(Distribot).not_to receive(:publish!)
          expect(Distribot).not_to receive(:broadcast!)

          # Finally:
          @handler.callback(@message)
        end
      end
    end
  end

  describe '#all_phase_handler_tasks_are_complete?(flow, phase)' do
    context 'when all tasks are complete' do
      before do
        @flow = Distribot::Flow.new(id: 123)
        handlers = ['handler1']
        task_counts = {
          "distribot.flow.123.phase1.handler1.tasks" => 0,
        }
        @phase = Distribot::Phase.new(name: 'phase1', handlers: [
          'handler1'
        ])
        expect(Distribot).to receive(:redis) do
          redis = double('redis')
          expect(redis).to receive(:get).exactly(1).times do |key|
            task_counts[key]
          end
          redis
        end
      end
      it 'returns true' do
        expect(described_class.new.all_phase_handler_tasks_are_complete?(@flow, @phase)).to be_truthy
      end
    end
    context 'when some tasks remain' do
      before do
        @flow = Distribot::Flow.new(id: 123)
        handlers = ['handler1']
        task_counts = {
          "distribot.flow.123.phase1.handler1.tasks" => 1,
        }
        @phase = Distribot::Phase.new(name: 'phase1', handlers: [
          'handler1'
        ])
        expect(Distribot).to receive(:redis) do
          redis = double('redis')
          expect(redis).to receive(:get).exactly(1).times do |key|
            task_counts[key]
          end
          redis
        end
      end
      it 'returns false' do
        expect(described_class.new.all_phase_handler_tasks_are_complete?(@flow, @phase)).to be_falsey
      end
    end
  end
end
