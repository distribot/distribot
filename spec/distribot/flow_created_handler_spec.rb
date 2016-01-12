require 'spec_helper'

describe Distribot::FlowCreatedHandler do
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.flow.created'
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
      @flow_id = SecureRandom.uuid
      expect(Distribot::Flow).to receive(:find).with(@flow_id) do
        flow = double('flow')
        expect(flow).to receive(:next_phase){'phase2'}
        expect(flow).to receive(:transition_to!).with('phase2'){ true }
        flow
      end
      expect(Distribot).to receive(:subscribe)
    end
    it 'transitions to the next phase' do
      expect(described_class.new.callback(flow_id: @flow_id)).to be_truthy
    end
  end
end
