require 'spec_helper'

describe Distribot::HandlerFinishedHandler do
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
    it 'subscribes to the distribot.workflow.handler.finished queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.handler.finished'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback' do

    it 'cancels all consumers for this handler\'s tasks\' queues' do
    end
    context 'when all the remaining tasks for each handler in this phase' do
      context 'are zero' do
        it 'publishes a message to the phase.finished queue'
      end
      context 'are not yet zero' do
        it 'does not publish to the phase.finished queue'
      end
    end
  end
end
