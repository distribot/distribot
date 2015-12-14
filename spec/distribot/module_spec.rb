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
      @topic = "queue-#{SecureRandom.uuid}"
      expect_any_instance_of(Distribot::Subscription).to receive(:start).with( @topic, {} )
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
      expect_any_instance_of(Distribot::MultiSubscription).to receive(:start).with( @topic, {} )
    end
    it 'subscribes properly' do
      Distribot.subscribe_multi(@topic) do |message|
        expect(message).to have_key :hello
        expect(message[:hello]).to eq 'world'
      end
    end
  end

end
