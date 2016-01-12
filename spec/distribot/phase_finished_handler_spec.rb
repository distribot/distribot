require 'spec_helper'

describe Distribot::PhaseFinishedHandler do
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.flow.phase.finished'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(Distribot).to receive(:subscribe)
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback( :flow_id, :phase )' do
    before do
      expect(Distribot).to receive(:subscribe)
    end
    context 'when flow is' do
      before do
        @flow = double('flow')
        @flow_id = 'xxx'
        expect(Distribot::Flow).to receive(:find).with(@flow_id) { @flow }
      end
      context 'still in :phase' do
        before do
          expect(@flow).to receive(:current_phase){ 'start' }
        end
        context 'and the flow' do
          context 'has a next phase' do
            before do
              expect(@flow).to receive(:next_phase).exactly(2).times{ 'finish' }
            end
            it 'tells the flow to transition to the next phase' do
              expect(@flow).to receive(:transition_to!).with('finish')
              described_class.new.callback(flow_id: @flow_id, phase: 'start')
            end
          end
          context 'does not have a next phase' do
            before do
              expect(@flow).to receive(:next_phase){ nil }
              expect(@flow).to receive(:id){ @flow_id }
            end
            it 'publishes to distribot.flow.finished' do
              expect(Distribot).to receive(:publish!).with('distribot.flow.finished', {
                flow_id: @flow_id
              })
              described_class.new.callback(flow_id: @flow_id, phase: 'start')
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
