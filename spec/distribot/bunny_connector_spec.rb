require 'spec_helper'

describe Distribot::BunnyConnector do

  describe '#initialize(connection_args={})' do
    before do
      @amqp_url = 'amqp://distribot:distribot@172.17.0.2:5672'
      expect(Bunny).to receive(:new).with(@amqp_url) do
        bunny = double('bunny')
        expect(bunny).to receive(:start).ordered
        bunny
      end
    end

    it 'initializes a new connector' do
      connector = described_class.new(@amqp_url)
      expect(connector).to be_a Distribot::BunnyConnector
    end

    it 'initializes subscribers as an empty array' do
      connector = described_class.new(@amqp_url)
      expect(connector.subscribers).to eq [ ]
    end
  end

  describe '#channel' do
    before do
      expect_any_instance_of(described_class).to receive(:setup)
      @connector = described_class.new
    end
    context 'the first time' do
      it 'creates a new channel and returns it' do
        bunny = double('bunny')
        expect(bunny).to receive(:create_channel){ 'a-channel' }
        expect(@connector).to receive(:bunny){ bunny }
        expect(@connector.channel).to eq 'a-channel'
      end
    end
    context 'after the first time' do
      it 'returns the same first channel' do
        bunny = double('bunny')
        expect(bunny).to receive(:create_channel).exactly(1).times{ 'a-channel' }
        expect(@connector).to receive(:bunny){ bunny }
        expect(@connector.channel).to eq 'a-channel'
        expect(@connector.channel).to eq 'a-channel'
      end
    end
  end

  describe '#queue_exists?(topic)' do
    before do
      expect_any_instance_of(described_class).to receive(:setup)
      @connector = described_class.new(nil)
      @topic = SecureRandom.uuid
      @bunny = double('bunny')
      expect(@connector).to receive(:bunny){ @bunny }
    end
    context 'when the queue' do
      context 'exists' do
        before do
          expect(@bunny).to receive(:queue_exists?).with(@topic){ true }
        end
        it 'returns true' do
          expect(@connector.queue_exists?(@topic)).to be_truthy
        end
      end
      context 'does not exist' do
        before do
          expect(@bunny).to receive(:queue_exists?).with(@topic){ false }
        end
        it 'returns false' do
          expect(@connector.queue_exists?(@topic)).to be_falsey
        end
      end
    end
  end

  describe '#subscribe(topic, options={}, &block)' do
    before do
      expect_any_instance_of(described_class).to receive(:setup)
      @connector = described_class.new(nil)
      @topic = SecureRandom.uuid
      expect_any_instance_of(Distribot::Subscription).to receive(:start).with(@topic, {}) do |&block|
        block.call( id: 'hello' )
      end
    end
    it 'subscribes to the topic, and calls the block when a message is received' do
      @connector.subscribe(@topic) do |msg|
        @id = msg[:id]
      end
      expect(@id).to eq 'hello'
    end
  end

  describe '#subscribe_multi(topic, options={}, &block)' do
    before do
      expect_any_instance_of(described_class).to receive(:setup)
      @connector = described_class.new(nil)
      @topic = SecureRandom.uuid
      expect_any_instance_of(Distribot::MultiSubscription).to receive(:start).with(@topic, {}) do |&block|
        block.call( id: 'hello' )
      end
    end
    it 'subscribes to the topic, and calls the block when a message is received' do
      @connector.subscribe_multi(@topic) do |msg|
        @id = msg[:id]
      end
      expect(@id).to eq 'hello'
    end
  end

  describe '#publish(topic, message)' do
    before do
      @topic = SecureRandom.uuid
      expect_any_instance_of(described_class).to receive(:setup)
      @connector = described_class.new
      @channel = double('channel')
      expect(@channel).to receive(:queue).with(@topic, auto_delete: true, durable: true) do
        queue = double('queue')
        expect(queue).to receive(:name){ @topic }
        queue
      end
      expect(@channel).to receive(:default_exchange) do
        exchange = double('exchange')
        expect(exchange).to receive(:publish).with( '{"hello":"world"}', routing_key: @topic)
        exchange
      end
      expect(@connector).to receive(:channel).exactly(2).times{ @channel }
    end
    it 'publishes the message' do
      @connector.publish(@topic, {hello: :world})
    end
  end

  describe '#broadcast(topic, message)' do
    before do
      @topic = SecureRandom.uuid
      expect_any_instance_of(described_class).to receive(:setup)
      @connector = described_class.new
      @channel = double('channel')
      expect(@channel).to receive(:fanout).with(@topic) do
        exchange = double('exchange')
        expect(exchange).to receive(:publish).with('{"hello":"world"}', routing_key: @topic)
        exchange
      end
      expect(@connector).to receive(:channel){ @channel }
    end
    it 'broadcasts a message on a fanout exchange' do
      @connector.broadcast(@topic, {hello: :world})
    end
  end

  describe '#stubbornly' do
    context 'when the block' do
      before do
        expect_any_instance_of(described_class).to receive(:setup)
      end
      context 'raises an error' do
        it 'keeps trying forever, until it stops raising an error' do
          @return_value = SecureRandom.uuid
          thing = described_class.new
          @max_tries = 3
          @total_tries = 0
          expect(thing.send(:stubbornly, :foo){
            if @total_tries >= @max_tries
              @return_value
            else
              @total_tries += 1
              raise Timeout::Error.new
            end
          }).to eq @return_value
        end
      end
      context 'does not raise an error' do
        it 'returns the result of the block' do
          @return_value = SecureRandom.uuid
          thing = described_class.new
          expect(thing.send(:stubbornly, :foo){ @return_value }).to eq @return_value
        end
      end
    end
  end
end
