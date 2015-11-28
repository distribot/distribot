require 'spec_helper'

describe Distribot::WorkflowFinishedHandler do
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
    it 'subscribes to the distribot.workflow.finished queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.finished'
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
      @workflow = Distribot::Workflow.new(id: @workflow_id, name: 'test-workflow')
    end
    context 'when the $workflow_id.finished queue' do
      context 'exists' do
        before do
          @queue_name = "distribot.workflow.#{@workflow_id}.finished"
          expect(Distribot).to receive(:queue_exists?).with(@queue_name){true}
          expect(Distribot::Workflow).to receive(:find).with(@workflow_id){ @workflow }
        end
        it 'sends a message to that queue' do
          expect(Distribot).to receive(:publish!).with(@queue_name, {workflow_id: @workflow_id}.to_json)
          described_class.new.callback(workflow_id: @workflow_id)
        end
      end
      context 'does not exist' do
        before do
          @queue_name = "distribot.workflow.#{@workflow_id}.finished"
          expect(Distribot).to receive(:queue_exists?).with(@queue_name){false}
          expect(Distribot::Workflow).to receive(:find).with(@workflow_id){ @workflow }
        end
        it 'does not send a message to that queue' do
          expect(Distribot).not_to receive(:publish!)
          described_class.new.callback(workflow_id: @workflow_id)
        end
      end
    end
  end
end
