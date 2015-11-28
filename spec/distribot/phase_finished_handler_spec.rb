require 'spec_helper'

describe Distribot::PhaseFinishedHandler do
  before :each do
    Distribot.stub(:queue) do
      queue = double('queue')
      queue.stub(:subscribe)
      queue
    end
    Distribot.stub(:publish!)
    Distribot.stub(:redis) do
      redis = double('redis')
      redis.stub(:set)
      redis.stub(:sadd)
      redis.stub(:get)
      redis.stub(:keys){ [] }
      redis.stub(:smembers){ [] }
      redis
    end
  end
  describe 'definition' do
    it 'subscribes to the distribot.workflow.phase.finished queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.phase.finished'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback' do
    context 'when the current_phase' do
      before do
        @workflow_id = SecureRandom.uuid
        @workflow = Distribot::Workflow.new(
          id: @workflow_id,
          name: 'test',
          phases: [
            {name: 'phase1', is_initial: true, handlers: ['Foo']}
          ]
        )
        @message = {
          workflow_id: @workflow_id
        }
        expect(Distribot::Workflow).to receive(:find).with(@workflow_id){@workflow}
      end
      context 'matches the phase that just ended' do
        before do
          expect(@workflow).to receive(:current_phase){ 'phase1' }
          @message[:phase] = 'phase1'
        end
        context 'when there is a next phase' do
          before do
            expect(@workflow).to receive(:next_phase).at_least(1).times{ 'phase2' }
            expect(@workflow).to receive(:transition_to!).with('phase2')
          end
          it 'tranisitions the workflow to the next phase' do
            described_class.new.callback(@message)
          end
        end
        context 'when there is not a next phase' do
          before do
            expect(@workflow).to receive(:next_phase).at_least(1).times
          end
          it 'publishes to the workflow.finished queue' do
            expect(Distribot).to receive(:publish!).with('distribot.workflow.finished', {
              workflow_id: @workflow_id
            }.to_json)
            described_class.new.callback(@message)
          end
        end
      end
      context 'does not match the phase that just ended' do
        before do
          expect(@workflow).to receive(:current_phase){ 'phase2' }
          @message[:phase] = 'phase1'
        end
        it 'does nothing' do
          expect(Distribot).not_to receive(:publish!)
          expect(@workflow).not_to receive(:transition_to!)
          described_class.new.callback(@message)
        end
      end
    end
  end
end
