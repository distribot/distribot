require 'spec_helper'

describe Distribot::WorkflowFinishedHandler do
  describe 'definition' do
    it 'subscribes to the distribot.workflow.finished queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.finished'
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
        workflow_id: 'xxx'
      }
      redis = double('redis')
      expect(redis).to receive(:decr).with('distribot.workflows.running')
      expect(redis).to receive(:srem).with('distribot.workflows.active', @message[:workflow_id])
      expect(Distribot).to receive(:redis).exactly(2).times{ redis }
      expect(Distribot).to receive(:subscribe)
    end
    it 'decrements the running tally of how many workflows are currently in process' do
      described_class.new.callback(@message)
    end
  end
end
