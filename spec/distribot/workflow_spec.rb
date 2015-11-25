require 'spec_helper'

describe Distribot::Workflow do
  before do
    @json = JSON.parse( File.read('spec/fixtures/simple_workflow.json'), symbolize_names: true )
  end
  it 'can be initialized' do
    workflow = Distribot::Workflow.new(
      id: SecureRandom.uuid,
      name: @json[:name],
      phases: @json[:phases]
    )
    expect(workflow.name).to eq @json[:name]
    expect(workflow.phases.count).to eq @json[:phases].count
  end

  describe '#redis_id' do
    before do
      @id = SecureRandom.uuid
      @workflow = Distribot::Workflow.new(
        id: @id,
        name: @json[:name],
        phases: @json[:phases]
      )
    end
    it 'returns the redis id' do
      expect(@workflow.redis_id).to eq 'distribot-workflow.search:' + @id
    end
  end

  describe '#save!' do
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
      redis = Distribot.redis
      current_history = @workflow.transitions
      @workflow.transition_to! 'searching'

    end
  end
end

