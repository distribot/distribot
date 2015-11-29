require 'spec_helper'

describe Distribot::PhaseFinishedHandler do
  before do
    Distribot.stub(:subscribe)
  end
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.phase.finished'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback( :workflow_id, :phase )' do
    before do
      @workflow_attrs = {
        name: 'finisher',
        phases: [
          {name: 'start', is_initial: true, transitions_to: 'phase1'},
        ]
      }
    end
    context 'when workflow is' do
      context 'still in :phase' do
        context 'and the workflow' do
          context 'has a next phase' do
            before do
              @workflow_attrs[:phases] << {
                name: 'phase1'
              }
              @workflow = Distribot::Workflow.create!(@workflow_attrs)
              expect(Distribot::Workflow).to receive(:find) { @workflow }
            end
            it 'tells the workflow to transition to the next phase' do
              expect(@workflow).to receive(:transition_to!).with('phase1')
              described_class.new.callback(workflow_id: @workflow.id, phase: 'start')
            end
          end
          context 'does not have a next phase' do
            before do
              @workflow_attrs[:phases].first.delete(:transitions_to)
              @workflow_attrs[:phases].first[:is_final] = true
              @workflow = Distribot::Workflow.create!(@workflow_attrs)
              expect(Distribot::Workflow).to receive(:find) { @workflow }
            end
            it 'publishes to distribot.workflow.finished' do
              expect(Distribot).to receive(:publish!).with('distribot.workflow.finished', {
                workflow_id: @workflow.id
              })
              described_class.new.callback(workflow_id: @workflow.id, phase: 'start')
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
