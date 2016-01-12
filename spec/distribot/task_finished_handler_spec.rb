require 'spec_helper'

describe Distribot::TaskFinishedHandler do
  before do
    Distribot.stub(:subscribe)
  end
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.flow.task.finished'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback(message)' do
    before do
      @message = {
        task_queue: 'task-queue',
        finished_queue: 'finished-queue',
        phase: 'the-phase',
        handler: 'the-hander',
        flow_id: 'flow-id'
      }
    end
    context 'when the redis task counter' do
      context 'is nil' do
        before do
          @redis = double('redis')
          expect(@redis).to receive(:get){ nil }
          expect(Distribot).to receive(:redis) do
            @redis
          end
        end
        it 'does nothing, because the handler is not yet finished' do
          # Finally, action:
          handler = Distribot::TaskFinishedHandler.new
          handler.callback(@message)
        end
      end
      context 'is not nil' do
        before do
          @redis = double('redis')
          expect(Distribot).to receive(:redis).at_least(1).times do
            @redis
          end
        end
        context 'when the task count after decrementing' do
          context 'is == 0' do
            before do
              expect(@redis).to receive(:get){ 0 }
              expect(@redis).to receive(:del).ordered
            end
            it 'publishes a message to the handler finished queue' do
              handler = Distribot::TaskFinishedHandler.new

              expect(Distribot).to receive(:publish!).with("distribot.flow.handler.finished", @message.except(:finished_queue))

              # Finally, action:
              handler.callback(@message)
            end
          end
        end
      end
    end
  end

end
