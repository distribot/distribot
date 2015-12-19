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
      @workflow = Distribot::Workflow.new(
        id: 'fake-id'
      )
    end
    it 'returns the redis id' do
      expect(@workflow.redis_id).to eq 'distribot-workflow:' + 'fake-id'
    end
  end

  describe '#save!' do
    before do
      @workflow = Distribot::Workflow.new(
        name: @json[:name],
        phases: @json[:phases]
      )
    end
    context 'when saving' do
      context 'fails' do
        context 'because the workflow already has an id' do
          before do
            @workflow.id = 'some-id'
          end
          it 'raises an error' do
            expect{@workflow.save!}.to raise_error StandardError
          end
        end
      end
      context 'succeeds' do
        before do
          # Fake id:
          expect(SecureRandom).to receive(:uuid){ 'xxx' }

          # Redis-saving:
          redis = double('redis')
          expect(redis).to receive(:set).with('distribot-workflow:xxx:definition', anything)
          expect(redis).to receive(:sadd).with('distribot.workflows.active', 'xxx')
          expect(@workflow).to receive(:redis).exactly(2).times{ redis }

          # Transition-making:
          expect(@workflow).to receive(:current_phase){ 'start' }
          expect(@workflow).to receive(:add_transition).with(hash_including(to: 'start'))

          # Announcement-publishing:
          expect(Distribot).to receive(:publish!).with('distribot.workflow.created', {
            workflow_id: 'xxx'
          })
        end
        context 'when a callback is provided' do
          before do
            expect(Thread).to receive(:new) do |&block|
              block.call
            end
            expect(@workflow).to receive(:finished?).ordered{false}
            expect(@workflow).to receive(:finished?).ordered{true}
          end
          it 'waits until finished, then calls the callback with {workflow_id: self.id}' do
            @callback_args = nil
            @workflow.save! do |info|
              @callback_args = info
            end
            expect(@callback_args).to eq(workflow_id: 'xxx')
          end
        end
        context 'when no callback is provided' do
          it 'saves it in redis' do
            @workflow.save!
          end
        end
      end
    end
  end

  describe '.create!' do
    before do
      expect_any_instance_of(Distribot::Workflow).to receive(:save!)
    end
    it 'saves the object and returns it' do
      workflow = Distribot::Workflow.create!(name: 'testy', phases: [ ])
      expect(workflow).to be_a Distribot::Workflow
    end
  end

  describe '.find' do
    before do
      expect(Distribot).to receive(:redis_id){ 'fake-redis-id' }
      expect(described_class).to receive(:redis) do
        redis = double('redis')
        expect(redis).to receive(:get).with('fake-redis-id:definition'){ @stored_json }
        redis
      end
    end
    context 'when it can be found' do
      before do
        @stored_json = @json.to_json
      end
      it 'returns the correct workflow' do
        expect(described_class.find('any-id')).to be_a described_class
      end
    end
    context 'when it cannot be found' do
      before do
        @stored_json = nil
      end
      it 'returns nil' do
        expect(described_class.find('any-id')).to be_nil
      end
    end
  end

  describe '#phase(name)' do
    before do
      @workflow = Distribot::Workflow.new(
        id: 'xxx',
        name: 'testy',
        phases: [{is_initial: true, name: 'testy'} ]
      )
    end
    context 'when the phase' do
      context 'exists' do
        it 'returns the phase object' do
          expect(@workflow.phase('testy')).to be_a Distribot::Phase
        end
      end
      context 'does not exist' do
        it 'returns nil' do
          expect(@workflow.phase('missing-phase')).to be_nil
        end
      end
    end
  end

  describe '#transition_to!(:phase_name)' do
    context 'when the workflow' do
      before do
        @workflow = Distribot::Workflow.new(
          id: 'xxx',
          name: 'testy',
          phases: [
            {is_initial: true, name: 'start'},
            {is_final: true, name: 'finish'},
          ]
        )
      end
      context 'did not have a previous phase' do
        before do
          @next_phase = 'start'
          expect(@workflow).to receive(:transitions){ [ ] }
          expect(Distribot).to receive(:publish!).with('distribot.workflow.phase.started', {
            workflow_id: @workflow.id,
            phase: @next_phase
          })
        end
        it 'stores a transition from nil to the new phase' do
          expect(@workflow).to receive(:add_transition).with(hash_including(from: nil, to: @next_phase))
          @workflow.transition_to!(@next_phase)
        end
      end
      context 'had a previous phase' do
        before do
          @next_phase = 'finish'
          expect(@workflow).to receive(:transitions) do
            [
              {from: nil, to: 'start'}
            ]
          end
          expect(Distribot).to receive(:publish!).with('distribot.workflow.phase.started', {
            workflow_id: @workflow.id,
            phase: @next_phase
          })
        end
        it 'stores a transition from the previous phase to the new phase' do
          expect(@workflow).to receive(:add_transition).with(hash_including(from: 'start', to: @next_phase))
          @workflow.transition_to!(@next_phase)
        end
      end
    end
  end

  describe '#current_phase' do
    before do
      @workflow = Distribot::Workflow.new(
        id: 'xxx',
        name: 'foobar',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when the workflow' do
      context 'has previous transitions' do
        before do
          expect(@workflow).to receive(:transitions) do
            [
              OpenStruct.new(from: nil,     to: 'start',  timestamp: 60.seconds.ago.to_i ),
              OpenStruct.new(from: 'start', to: 'finish', timestamp: 30.seconds.ago.to_i )
            ]
          end
        end
        it 'returns the "to" value of the latest transition' do
          expect(@workflow.current_phase).to eq 'finish'
        end
      end
      context 'has no previous transitions' do
        before do
          expect(@workflow).to receive(:transitions){ [ ] }
        end
        it 'returns the first is_initial:true phase name' do
          expect(@workflow.current_phase).to eq 'start'
        end
      end
    end
  end

  describe '#next_phase' do
    before do
      @workflow = Distribot::Workflow.new(
        id: 'xxx',
        name: 'foobar',
        phases: [
          {name: 'step1', is_initial: true, transitions_to: 'step2'},
          {name: 'step2', is_final: true},
        ]
      )
    end
    context 'when there is a next phase' do
      before do
        expect(@workflow).to receive(:current_phase){ 'step1' }
      end
      it 'returns the next phase name' do
        expect(@workflow.next_phase).to eq 'step2'
      end
    end
    context 'when there is no next phase' do
      before do
        expect(@workflow).to receive(:current_phase){ 'step2' }
      end
      it 'returns nil' do
        expect(@workflow.next_phase).to be_nil
      end
    end
  end

  describe '#pause!' do
    context 'when running' do
      it 'pauses'
    end
    context 'when already paused' do
      it 'raises an exception'
    end
  end
  describe '#paused?' do
    context 'when paused' do
      it 'returns true'
    end
    context 'when not paused' do
      it 'returns false'
    end
  end
  describe '#resume!' do
    context 'when paused' do
      it 'transitions back to the last phase transitioned to'
    end
    context 'when not paused' do
      it 'raises an exception'
    end
  end
  describe '#cancel!' do
    context 'when running' do
      it 'cancels the workflow'
    end
    context 'when not running' do
      it 'raises an exception'
    end
  end
  describe '#canceled?' do
    context 'when canceled' do
      it 'returns true'
    end
    context 'when not canceled' do
      it 'returns false'
    end
  end
  describe '#running?' do
    context 'when paused' do
      it 'returns false'
    end
    context 'when canceled' do
      it 'returns false'
    end
    context 'when finished' do
      it 'returns false'
    end
    context 'when neither canceled, paused nor finished' do
      it 'returns true'
    end
  end

  describe '#stubbornly' do
    context 'when the block' do
      context 'raises an error' do
        it 'keeps trying forever, until it stops raising an error' do
          @return_value = SecureRandom.uuid
          workflow = described_class.new
          @max_tries = 3
          @total_tries = 0
          expect(workflow).to receive(:warn).exactly(3).times
          expect(workflow.stubbornly(:foo){
            if @total_tries >= @max_tries
              @return_value
            else
              @total_tries += 1
              raise NoMethodError.new
            end
          }).to eq @return_value
        end
      end
      context 'does not raise an error' do
        it 'returns the result of the block' do
          @return_value = SecureRandom.uuid
          workflow = described_class.new
          expect(workflow.stubbornly(:foo){ @return_value }).to eq @return_value
        end
      end
    end
  end
end

