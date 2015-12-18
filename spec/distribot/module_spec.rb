require 'spec_helper'

describe Distribot do
  describe '.debug' do
    it 'allows true and false values' do
      Distribot.debug = true
      expect(Distribot.debug).to be_truthy
      Distribot.debug = false
      expect(Distribot.debug).to be_falsey
    end
  end

  describe '.configure' do
    it 'executes the given block and uses the result as the configuration' do
      Distribot.reset_configuration!
      Distribot.configuration
      Distribot.configure do |config|
        config.foo=:bar
      end
      expect(Distribot.configuration.foo).to eq :bar
    end
  end

  describe '.redis' do
    before do
      Distribot.reset_configuration!
      Distribot.configure do |config|
        config.redis_url = nil
      end
    end
    it 'returns a new Redis instance' do
      expect(Redis).to receive(:new){ 'HELLO' }
      expect(Distribot.redis).to eq 'HELLO'
    end
  end

  describe '.connector' do
    before do
      Distribot.configure do |config|
        config.rabbitmq_url = 'fake-rabbit-url'
      end
    end
    it 'returns a BunnyConnector' do
      expect(Distribot::BunnyConnector).to receive(:new).with('fake-rabbit-url'){ 'connector' }
      expect(Distribot.connector).to eq 'connector'
    end
  end

  describe '.queue_exists?(name)' do
    context 'when the queue exists' do
      before do
        @queue_name = "queue-#{SecureRandom.uuid}"
        expect(Distribot).to receive(:connector) do
          connector = double('connector')
          expect(connector).to receive(:queue_exists?).with(@queue_name){ true }
          connector
        end
      end
      it 'returns true' do
        expect(Distribot.queue_exists?(@queue_name)).to be_truthy
      end
    end
    context 'when the queue does not exist' do
      before do
        @queue_name = "queue-#{SecureRandom.uuid}"
        expect(Distribot).to receive(:connector) do
          connector = double('connector')
          expect(connector).to receive(:queue_exists?).with(@queue_name){ false }
          connector
        end
      end
      it 'returns false' do
        expect(Distribot.queue_exists?(@queue_name)).to be_falsey
      end
    end
  end

  describe '.subscribe(queue_name, options={}, &block)' do
    before do
      @topic = "queue-#{SecureRandom.uuid}"
      expect(Distribot).to receive(:connector) do
        connector = double('connector')
        expect(connector).to receive(:subscribe).with(@topic, {}) do |&block|
          block.call( hello: 'world' )
        end
        connector
      end
    end
    it 'subscribes properly' do
      Distribot.subscribe(@topic) do |message|
        expect(message).to have_key :hello
        expect(message[:hello]).to eq 'world'
      end
    end
  end

  describe '.subscribe_multi(topic, options={}, &block)' do
    before do
      @topic = "queue-#{SecureRandom.uuid}"
      expect(Distribot).to receive(:connector) do
        connector = double('connector')
        expect(connector).to receive(:subscribe_multi).with(@topic, {}) do |&block|
          block.call( hello: 'world' )
        end
        connector
      end
    end
    it 'subscribes properly' do
      Distribot.subscribe_multi(@topic) do |message|
        expect(message).to have_key :hello
        expect(message[:hello]).to eq 'world'
      end
    end
  end

  describe '.publish!(topic, data)' do
    before do
      @topic = SecureRandom.uuid
      @data = { id: SecureRandom.uuid }
      expect(Distribot).to receive(:connector) do
        connector = double('connector')
        expect(connector).to receive(:publish).with(@topic, @data)
        connector
      end
    end
    it 'publishes the message to the topic' do
      Distribot.publish!(@topic, @data)
    end
  end

  describe '.broadcast!(topic, data)' do
    before do
      @topic = SecureRandom.uuid
      @data = { id: SecureRandom.uuid }
      expect(Distribot).to receive(:connector) do
        connector = double('connector')
        expect(connector).to receive(:broadcast).with(@topic, @data)
        connector
      end
    end
    it 'publishes the message to the topic' do
      Distribot.broadcast!(@topic, @data)
    end
  end

end
