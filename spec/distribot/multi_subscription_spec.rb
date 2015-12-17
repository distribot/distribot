require 'spec_helper'

describe Distribot::MultiSubscription do
  describe 'inheritance' do
    let(:subject){ described_class.new(nil) }
    it { should be_a Distribot::ConnectionSharer }
  end

  describe '#start(topic, options={}, &block)' do
    it 'subscribes to the rabbit queue' do
      # Arrange:
      @topic = 'my.topic'
      subscription = described_class.new(nil)

      queue = double('queue')
      channel = double('channel')
      expect(channel).to receive(:queue).with('', exclusive: true, auto_delete: true){ queue }
      expect(channel).to receive(:fanout).with(@topic){ 'exchange' }
      expect(queue).to receive(:bind).with('exchange') do
        exchange = double('exchange')
        expect(exchange).to receive(:subscribe) do |&block|
          block.call(nil, nil, {id: :good_message} )
          block.call(nil, nil, {id: :bad_message} )
        end
        exchange
      end
      expect(subscription).to receive(:channel).exactly(2).times{ channel }

      # Act:
      subscription.start(@topic) do |msg|
        raise "Test error" if msg[:id] == 'bad_message'
      end

      # Assert:
    end
  end
end
