require 'spec_helper'

describe Distribot::TaskFinishedHandler do
  before do
    Distribot.stub(:subscribe)
  end
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.handler.enumerated'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback( :finished_queue )' do
    it 'subscribes to the :finished_queue' do
      handler = described_class.new
      expect(Distribot).to receive(:subscribe).with('foobar')
      handler.callback(finished_queue: 'foobar')
    end
  end

  describe '#handle_task_finished(message, task_info)' do
    context 'when the redis task counter' do
      context 'is nil' do
        it 'does nothing, because the handler is not yet finished'
      end
      context 'is not nil' do
        it 'decrements the redis task counter by 1'
        context 'when the task count after decrementing' do
          context 'is <= 0' do
            it 'publishes a message to the handler finished queue'
            it 'cancels any local consumers of the "finished_queue" for that $workflow.$phase.$handler'
          end
          context 'is > 0' do
            it 'does nothing, because the handler is not yet finished'
          end
        end
      end
    end
  end
end
