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
end
