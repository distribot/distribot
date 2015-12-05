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
      Distribot.configure do |config|
        config.foo=:bar
      end
      expect(Distribot.configuration.foo).to eq :bar
    end
  end

  describe '.bunny' do
    before do
      Distribot.configure do |config|
        config.rabbitmq_url = nil
      end
    end
    it 'returns a new Bunny instance' do
      expect(Distribot.bunny).to be_a Bunny::Session
    end
  end

  describe '.redis' do
    before do
      Distribot.configure do |config|
        config.redis_url = nil
      end
    end
    it 'returns a new Redis instance' do
      expect(Distribot.redis).to be_a Redis
    end
  end

  describe '.queue_exists?(name)' do
    context 'when the queue exists' do
      before do
        @queue_name = "queue-#{SecureRandom.uuid}"
        expect_any_instance_of(Bunny::Session).to receive(:queue_exists?).with(@queue_name){ true }
      end
      it 'returns true' do
        expect(Distribot.queue_exists?(@queue_name)).to be_truthy
      end
    end
    context 'when the queue does not exist' do
      before do
        @queue_name = "queue-#{SecureRandom.uuid}"
        expect_any_instance_of(Bunny::Session).to receive(:queue_exists?).with(@queue_name){ false }
      end
      it 'returns false' do
        expect(Distribot.queue_exists?(@queue_name)).to be_falsey
      end
    end
  end

  describe '.subscribe(queue_name, options={}, &block)' do
    before do
      @prefetch_size = 1
      @queue_name = "queue-#{SecureRandom.uuid}"
      delivery_info = double('delivery_info')
      delivery_tag = "delivery-tag-#{SecureRandom.uuid}"
      expect(delivery_info).to receive(:delivery_tag){ @delivery_tag }
      expect_any_instance_of(Bunny::Channel).to receive(:acknowledge).with( @delivery_tag, false)
      expect_any_instance_of(Bunny::Queue).to receive(:subscribe).with({manual_ack: true}) do |args, &block|
        block.call(delivery_info, '', {hello: :world}.to_json)
      end
    end
    it 'subscribes properly' do
      Distribot.subscribe(@queue_name) do |message|
        expect(message).to have_key :hello
        expect(message[:hello]).to eq 'world'
      end
    end
  end

  describe '.subscribe_multi(topic, options={}, &block)' do
    before do
      @prefetch_size = 1
      @topic = "queue-#{SecureRandom.uuid}"
      expect_any_instance_of(Bunny::Channel).to receive(:prefetch).with( @prefetch_size )
      exchange = double('exchange')
      expect_any_instance_of(Bunny::Channel).to receive(:queue).with('', exclusive: true, auto_delete: true) do
        queue = double('queue')
        expect(queue).to receive(:bind).with(exchange){ queue }
        expect(queue).to receive(:subscribe) do |args={}, &block|
          block.call(nil, nil, {hello: :world}.to_json)
        end
        queue
      end
      expect_any_instance_of(Bunny::Channel).to receive(:fanout).with("distribot.fanout.#{@topic}"){ exchange }
    end
    it 'subscribes properly' do
      Distribot.subscribe_multi(@topic) do |message|
        expect(message).to have_key :hello
        expect(message[:hello]).to eq 'world'
      end
    end
  end

end
