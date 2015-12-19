require 'spec_helper'

describe Distribot::ConnectionSharer do
  describe '#initialize(bunny)' do
    before do
      @bunny = SecureRandom.uuid
      @sharer = described_class.new(@bunny)
    end
    it 'sets self.bunny' do
      expect(@sharer.bunny).to eq @bunny
    end
  end

  describe '#channel' do
    before do
      @bunny = double('bunny')
      expect(@bunny).to receive(:create_channel){ SecureRandom.uuid }
      @sharer = described_class.new(@bunny)
    end
    context 'the first time' do
      it 'creates a new channel and stores it' do
        expect(SecureRandom).to receive(:uuid){ 'your-channel' }
        expect(@sharer.channel).to eq 'your-channel'
      end
    end
    context 'each subsequent time' do
      it 'returns the original channel' do
        expect(SecureRandom).to receive(:uuid).exactly(1).times.and_call_original
        first_channel = @sharer.channel
        expect(@sharer.channel).to eq first_channel
      end
    end
  end
end
