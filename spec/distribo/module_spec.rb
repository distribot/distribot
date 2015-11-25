require 'spec_helper'

describe Distribo do
  describe '.debug' do
    it 'allows true and false values' do
      Distribo.debug = true
      expect(Distribo.debug).to be_truthy
      Distribo.debug = false
      expect(Distribo.debug).to be_falsey
    end
  end

  describe '.configure' do
    it 'executes the given block and uses the result as the configuration' do
      Distribo.configure do |config|
        config.foo=:bar
      end
      expect(Distribo.configuration.foo).to eq :bar
    end
  end

  describe '.bunny' do
    before do
      Distribo.configure do |config|
        config.rabbitmq_url = nil
      end
    end
    it 'returns a new Bunny instance' do
      expect(Distribo.bunny).to be_a Bunny::Session
    end
  end
end
