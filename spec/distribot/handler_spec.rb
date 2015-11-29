require 'spec_helper'

describe Distribot::Handler do
  before do
    Distribot.stub(:subscribe)
    Distribot.stub(:subscribe_multi)
  end
  describe '.subscribe_to' do
    context 'when fanout:truthy' do
      before do
        @id = SecureRandom.hex(8)
        @queue_name = "queue-#{@id}"
        @klass_name = "Foo#{@id}"
        expect(Distribot).to receive(:subscribe_multi).with(@queue_name)
      end
      it 'subscribes to the regular queue provided' do
        eval <<-EOF
        class #{@klass_name}
          include Distribot::Handler
          subscribe_to '#{@queue_name}', fanout: true, handler: :callback
          def callback(message)
          end
        end
        EOF
        Kernel.const_get(@klass_name).new
      end
    end
    context 'when fanout:falsey' do
      before do
        @id = SecureRandom.hex(8)
        @queue_name = "queue-#{@id}"
        @klass_name = "Foo#{@id}"
        expect(Distribot).to receive(:subscribe).with(@queue_name)
      end
      it 'subscribes to the regular queue provided' do
        eval <<-EOF
        class #{@klass_name}
          include Distribot::Handler
          subscribe_to '#{@queue_name}', handler: :callback
          def callback(message)
          end
        end
        EOF
        Kernel.const_get(@klass_name).new
      end
    end
  end
end
