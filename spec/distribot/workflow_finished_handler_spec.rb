require 'spec_helper'

describe Distribot::WorkflowFinishedHandler do
  before :each do
    Distribot.stub(:publish!)
  end
  describe 'definition' do
    it 'subscribes to the distribot.workflow.finished queue' do
      expect(Distribot::Handler.queue_for(described_class)).to eq 'distribot.workflow.finished'
    end
    it 'declares a valid handler' do
      expect(Distribot::Handler.handler_for(described_class)).to eq :callback
    end
    it 'has a method matching the handler name' do
      expect(described_class.new).to respond_to :callback
    end
  end

  describe '#callback' do
    before do
      @workflow = Distribot::Workflow.create!(
        name: 'test-workflow',
        phases: [
          {name: 'start', is_initial: true, transitions_to: 'working'},
          {name: 'working', handlers: ['ExampleHandler'], transitions_to: 'finished'},
          {name: 'finished', is_final: true}
        ]
      )
      @workflow_id = @workflow.id
    end
    context 'exists' do
      before do
        @queue_name = "distribot.workflow.#{@workflow_id}.finished.callback"
        expect(Distribot::Workflow).to receive(:find).with(@workflow_id){ @workflow }
      end
      it 'decrements the running tally of how many workflows are currently in process' do
        redis_decr = double('redis-decr')
        expect(redis_decr).to receive(:decr).with('distribot.workflows.running')
        expect(Distribot).to receive(:redis).ordered{ redis_decr }
        described_class.new.callback(workflow_id: @workflow_id)
      end
    end
  end
end
