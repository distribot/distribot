require 'spec_helper'

describe Distribot::WorkflowCreatedHandler do
  before :each do
    Distribot.stub(:subscribe)
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
    it 'subscribes to the distribot.workflow.created queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.created'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback' do
    before do
      @workflow_id = SecureRandom.uuid
      expect(Distribot::Workflow).to receive(:find).with(@workflow_id) do
        workflow = double('workflow')
        expect(workflow).to receive(:next_phase){'phase2'}
        expect(workflow).to receive(:transition_to!).with('phase2'){ true }
        workflow
      end
    end
    it 'transitions to the next phase' do
      expect(Distribot::WorkflowCreatedHandler.new.callback(workflow_id: @workflow_id)).to be_truthy
    end
  end
end
