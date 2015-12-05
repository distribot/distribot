require 'spec_helper'

describe Distribot::TaskFinishedHandler do
  before do
    Distribot.stub(:subscribe)
  end
  describe 'definition' do
    it 'subscribes to the correct queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.handler.enumerated'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback( :finished_queue )' do
    it 'subscribes to the :finished_queue' do
      handler = described_class.new
      expect(Distribot).to receive(:subscribe).with('foobar')
      handler.callback(finished_queue: 'foobar')
    end
  end

  describe '#handle_task_finished(message, task_info)' do
    before do
      @message = {
        task_queue: 'task-queue',
        finished_queue: 'finished-queue',
        phase: 'the-phase',
        handler: 'the-hander',
        workflow_id: 'workflow-id'
      }
    end
    context 'when the redis task counter' do
      context 'is nil' do
        before do
          @redis = double('redis')
          expect(@redis).to receive(:get).with(@message[:task_queue]){ nil }
          expect(Distribot).to receive(:redis) do
            @redis
          end
        end
        it 'does nothing, because the handler is not yet finished' do
          # Define what 'does nothing' means:
          expect(@redis).not_to receive(:decr)

          # Finally, action:
          handler = Distribot::TaskFinishedHandler.new
          handler.handle_task_finished(@message, nil)
        end
      end
      context 'is not nil' do
        before do
          @redis = double('redis')
          expect(@redis).to receive(:get).with(@message[:task_queue]){ 1 }
          expect(Distribot).to receive(:redis).at_least(1).times do
            @redis
          end
        end
        context 'when the task count after decrementing' do
          context 'is <= 0' do
            before do
              expect(@redis).to receive(:decr).with(@message[:task_queue]){ 0 }
            end
            it 'publishes a message to the handler finished queue' do
              handler = Distribot::TaskFinishedHandler.new

              expect(Distribot).to receive(:publish!).with("distribot.workflow.handler.finished", @message.except(:finished_queue))
              expect(handler).to receive(:cancel_consumers_for).with(@message[:finished_queue])

              # Finally, action:
              handler.handle_task_finished(@message, nil)
            end
            it 'cancels any local consumers of the "finished_queue" for that $workflow.$phase.$handler'
          end
          context 'is > 0' do
            before do
              expect(@redis).to receive(:decr).with(@message[:task_queue]){ 1 }
            end
            it 'does nothing after redis.decr, because the handler is not yet finished' do
              expect(Distribot).not_to receive(:publish!)

              # Finally, action:
              handler = Distribot::TaskFinishedHandler.new
              handler.handle_task_finished(@message, nil)
            end
          end
        end
      end
    end
  end

  describe '#cancel_consumers_for(finished_queue)' do
    context 'when there are matching consumers' do
      it 'cancels them' do
        @handler = described_class.new

        matching_consumer = double('matching_consumer')
        expect(matching_consumer).to receive(:queue) do
          queue = double('queue')
          expect(queue).to receive(:name){ 'foo' }
          queue
        end
        expect(matching_consumer).to receive(:cancel)

        nonmatching_consumer = double('nonmatching_consumer')
        expect(nonmatching_consumer).to receive(:queue) do
          queue = double('queue')
          expect(queue).to receive(:name){ 'bar' }
          queue
        end
        expect(nonmatching_consumer).not_to receive(:cancel)
        @handler.consumers << matching_consumer
        @handler.consumers << nonmatching_consumer

        # Finally:
        @handler.cancel_consumers_for('foo')
      end
    end
    context 'when there are no matching consumers' do
      it 'does not cancel them' do
        described_class.new.cancel_consumers_for('foo')
      end
    end
  end

  describe '#callback(message)' do
    before do
      @message = {
        task_queue: 'task-queue',
        finished_queue: 'finished-queue',
        phase: 'the-phase',
        handler: 'the-hander',
        workflow_id: 'workflow-id'
      }
      @handler = described_class.new

      expect(Distribot).to receive(:subscribe).with(@message[:finished_queue]) do |&block|
        task_info = { }
        expect(@handler).to receive(:handle_task_finished).with(@message, task_info)
        block.call(task_info)
      end

      @handler.callback(@message)
    end
    it 'subscribes with a callback to #handle_task_finished' do

    end
  end
end
