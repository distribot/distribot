require 'spec_helper'

describe Distribot::FlowFinishedHandler do
  describe 'definition' do
    it 'subscribes to the distribot.flow.finished queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.flow.finished'
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
      @message = {
        flow_id: 'xxx'
      }
      redis = double('redis')
      expect(redis).to receive(:decr).with('distribot.flows.running')
      expect(redis).to receive(:srem).with('distribot.flows.active', @message[:flow_id])
      expect(Distribot).to receive(:redis).exactly(2).times{ redis }
      expect(Distribot).to receive(:subscribe)
    end
    it 'decrements the running tally of how many flows are currently in process' do
      described_class.new.callback(@message)
    end
  end
end
