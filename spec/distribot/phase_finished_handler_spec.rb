require 'spec_helper'

describe Distribot::PhaseFinishedHandler do
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.phase.finished'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(Distribot).to receive(:subscribe)
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback( :workflow_id, :phase )' do
    before do
      expect(Distribot).to receive(:subscribe)
    end
    context 'when workflow is' do
      before do
        @workflow = double('workflow')
        @workflow_id = 'xxx'
        expect(Distribot::Workflow).to receive(:find).with(@workflow_id) { @workflow }
      end
      context 'still in :phase' do
        before do
          expect(@workflow).to receive(:current_phase){ 'start' }
        end
        context 'and the workflow' do
          context 'has a next phase' do
            before do
              expect(@workflow).to receive(:next_phase){ 'finish' }
            end
            it 'tells the workflow to transition to the next phase' do
              expect(@workflow).to receive(:transition_to!).with('finish')
              described_class.new.callback(workflow_id: @workflow_id, phase: 'start')
            end
          end
          context 'does not have a next phase' do
            before do
              expect(@workflow).to receive(:next_phase){ nil }
              expect(@workflow).to receive(:id){ @workflow_id }
            end
            it 'publishes to distribot.workflow.finished' do
              expect(Distribot).to receive(:publish!).with('distribot.workflow.finished', {
                workflow_id: @workflow_id
              })
              described_class.new.callback(workflow_id: @workflow_id, phase: 'start')
            end
          end
        end
      end
      context 'no longer in :phase' do
        it 'does nothing'
      end
    end
  end

end
