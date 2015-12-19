require 'spec_helper'

describe Distribot::Subscription do
  describe 'inheritance' do
    let(:subject){ described_class.new(nil) }
    it { should be_a Distribot::ConnectionSharer }
  end

  describe '#start(topic, options={}, &block)' do
    it 'subscribes to the rabbit queue' do
      # Arrange:
      @topic = 'my.topic'
      subscription = described_class.new(nil)

      channel = double('channel')
      expect(channel).to receive(:queue).ordered.with(@topic, anything) do
        queue = double('queue')
        expect(queue).to receive(:subscribe).with(hash_including(manual_ack: true)) do |args, &block|
          # Send a good message:
          delivery_info1 = OpenStruct.new(delivery_tag: 'tag1')
          delivery_info2 = OpenStruct.new(delivery_tag: 'tag2')
          block.call(delivery_info1, nil, {id: :good_message}.to_json )
          block.call(delivery_info2, nil, {id: :bad_message}.to_json )
        end
        queue
      end
      expect(channel).to receive(:acknowledge).with('tag1', false)
      expect(channel).to receive(:basic_reject).with('tag2', true)

      expect(subscription).to receive(:channel).exactly(3).times{ channel }

      # Act:
      subscription.start(@topic) do |msg|
        raise "Test error" if msg[:id] == 'bad_message'
      end

      # Assert:
    end
  end
end
