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
      expect(Distribot.redis).to be_a Bunny::Session
    end

  end
end
