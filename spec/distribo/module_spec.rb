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
end
