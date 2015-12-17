
require 'spec_helper'

describe Distribot::Connector do

  describe '#initialize(connection_args={})' do
    before do
      @amqp_url = 'amqp://distribot:distribot@172.17.0.2:5672'
      expect(Bunny).to receive(:new).with(@amqp_url) do
        bunny = double('bunny')
        expect(bunny).to receive(:start).ordered
        expect(bunny).to receive(:create_channel).ordered do
          channel = double('channel')
          expect(channel).to receive(:prefetch).with(1)
          channel
        end
        bunny
      end
    end

    it 'initializes a new connector' do
      connector = described_class.new(@amqp_url)
      expect(connector).to be_a Distribot::Connector
    end
  end

  describe '#queues' do
    before do
      expect_any_instance_of(described_class).to receive(:setup)
      @connector = described_class.new
      @queues = %w(
        distribot.workflow.created
        distribot.workflow.finished
        distribot.workflow.handler.CheapWorker.1.0.0.enumerate
        distribot.workflow.handler.CheapWorker.1.0.0.tasks
        distribot.workflow.handler.FastWorker.1.0.0.enumerate
        distribot.workflow.handler.FastWorker.1.0.0.tasks
        distribot.workflow.handler.ForeignWorker.1.0.0.enumerate
        distribot.workflow.handler.ForeignWorker.1.0.0.tasks
        distribot.workflow.handler.GoodWorker.1.0.0.enumerate
        distribot.workflow.handler.GoodWorker.1.0.0.tasks
        distribot.workflow.handler.HardWorker.1.0.0.enumerate
        distribot.workflow.handler.HardWorker.1.0.0.tasks
        distribot.workflow.handler.SlowWorker.1.0.0.enumerate
        distribot.workflow.handler.SlowWorker.1.0.0.tasks
        distribot.workflow.handler.finished
        distribot.workflow.phase.finished
        distribot.workflow.phase.started
        distribot.workflow.task.finished
      )
      @queues_json = @queues.to_a.map{|name| {name: name} }.to_json
      Wrest.logger = Logger.new('/dev/null')
      stub_request(:get, "http://localhost:15672/api/queues").
        with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => @queues_json, :headers => {'Content-Type' => 'application/json'})
    end
    it 'returns all the queues from /api/queues on rabbitmq' do
      result = @connector.queues
      expect(result).to eq(@queues)
    end
  end

end
