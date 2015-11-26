require 'spec_helper'

describe Distribot::Workflow do
  before do
    @json = JSON.parse( File.read('spec/fixtures/simple_workflow.json'), symbolize_names: true )
  end
  it 'can be initialized' do
    workflow = Distribot::Workflow.new(
      name: @json[:name],
      phases: @json[:phases]
    )
    expect(workflow.name).to eq @json[:name]
    expect(workflow.phases.count).to eq @json[:phases].count
  end

  describe '#redis_id' do
    before do
      expect(SecureRandom).to receive(:uuid){ 'xxxxx' }
      @workflow = Distribot::Workflow.new(
        name: @json[:name],
        phases: @json[:phases]
      )
      @workflow.save!
    end
    it 'returns the redis id' do
      expect(@workflow.redis_id).to eq 'distribot-workflow:' + 'xxxxx'
    end
  end

  describe '#save!' do
    before do
      @workflow = Distribot::Workflow.new(
        name: @json[:name],
        phases: @json[:phases]
      )
      @workflow.save!
    end
    it 'saves it in redis' do
      redis = Distribot.redis
      expect(redis.keys).to include @workflow.redis_id + ':definition'
      expect(redis.keys).to include @workflow.redis_id + ':transitions'
    end
  end

  describe '#transition_to!(:phase_name)' do
    before do
      @id = SecureRandom.uuid
      @workflow = Distribot::Workflow.new(
        id: @id,
        name: @json[:name],
        phases: @json[:phases]
      )
      @workflow.save!
    end
    it 'saves it in redis' do
      @workflow.transition_to! 'searching'
      expect(@workflow.transitions.map{|x| x[:to]}).to include 'searching'
    end
  end

  describe '#current_phase' do
    before do
      @workflow = Distribot::Workflow.new(
        name: 'foobar',
        phases: [
          {name: 'step1', is_initial: true},
          {name: 'step2', is_final: true},
        ]
      )
      @workflow.save!
    end
    context 'when the workflow is new' do
      it 'returns the first phase marked with is_initial=true' do
        expect(@workflow.current_phase).to eq 'step1'
      end
    end
    context 'when the workflow has previous transitions' do
      before do
        @workflow.transition_to! 'step2'
      end
      it 'returns the latest phase the workflow transitioned into' do
        expect(@workflow.current_phase).to eq 'step2'
      end
    end
  end

  describe '#next_phase' do
    before do
      @workflow = Distribot::Workflow.new(
        name: 'foobar',
        phases: [
          {name: 'step1', is_initial: true, transitions_to: 'step2'},
          {name: 'step2', is_final: true},
        ]
      )
      @workflow.save!
    end
    context 'when there is a next phase' do
      it 'returns the next phase name' do
        expect(@workflow.next_phase).to eq 'step2'
      end
    end
    context 'when there is no next phase' do
      before do
        @workflow.transition_to! 'step2'
      end
      it 'returns nil' do
        expect(@workflow.next_phase).to be_nil
      end
    end
  end
end

