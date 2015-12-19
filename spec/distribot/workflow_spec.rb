require 'spec_helper'

describe Distribot::Workflow do
  before do
    @json = JSON.parse( File.read('spec/fixtures/simple_workflow.json'), symbolize_names: true )
  end
  it 'can be initialized' do
    workflow = Distribot::Workflow.new(
      phases: @json[:phases]
    )
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
      workflow = Distribot::Workflow.create!(phases: [ ])
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
    before do
      @workflow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when running' do
      before do
        expect(@workflow).to receive(:running?){ true }
        expect(@workflow).to receive(:current_phase){ 'start' }
        expect(@workflow).to receive(:add_transition).with(hash_including(
          from: 'start',
          to: 'paused'
        ))
      end
      it 'pauses' do
        @workflow.pause!
      end
    end
    context 'when not running' do
      before do
        expect(@workflow).to receive(:running?){ false }
        expect(@workflow).not_to receive(:current_phase)
        expect(@workflow).not_to receive(:add_transition)
      end
      it 'raises an exception' do
        expect{@workflow.pause!}.to raise_error Distribot::NotRunningError
      end
    end
  end
  describe '#paused?' do
    before do
      @workflow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when paused' do
      before do
        expect(@workflow).to receive(:current_phase){ 'paused' }
      end
      it 'returns true' do
        expect(@workflow.paused?).to be_truthy
      end
    end
    context 'when not paused' do
      before do
        expect(@workflow).to receive(:current_phase){ 'start' }
      end
      it 'returns false' do
        expect(@workflow.paused?).to be_falsey
      end
    end
  end
  describe '#resume!' do
    before do
      @workflow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when paused' do
      before do
        expect(@workflow).to receive(:paused?){ true }
        expect(@workflow).to receive(:transitions) do
          to_start = {from: nil, to: 'start', timestamp: 60.seconds.ago.to_f}
          to_paused = {from: 'start', to: 'paused', timestamp: 30.seconds.ago.to_f}
          [to_start, to_paused].map{|x| OpenStruct.new x }
        end
        expect(@workflow).to receive(:add_transition).with(hash_including(
          from: 'paused',
          to: 'start'
        ))
      end
      it 'transitions back to the last phase transitioned to' do
        @workflow.resume!
      end
    end
    context 'when not paused' do
      before do
        expect(@workflow).to receive(:paused?){ false }
      end
      it 'raises an exception' do
        expect{@workflow.resume!}.to raise_error Distribot::NotPausedError
      end
    end
  end
  describe '#cancel!' do
    before do
      @workflow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when running' do
      before do
        expect(@workflow).to receive(:running?){ true }
        expect(@workflow).to receive(:current_phase){ 'start' }
        expect(@workflow).to receive(:add_transition).with(hash_including(
          from: 'start',
          to: 'canceled'
        ))
      end
      it 'cancels the workflow' do
        @workflow.cancel!
      end
    end
    context 'when not running' do
      before do
        expect(@workflow).to receive(:running?){ false }
        expect(@workflow).not_to receive(:current_phase)
        expect(@workflow).not_to receive(:add_transition)
      end
      it 'raises an exception' do
        expect{@workflow.cancel!}.to raise_error Distribot::NotRunningError
      end
    end
  end
  describe '#canceled?' do
    before do
      @workflow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when canceled' do
      before do
        expect(@workflow).to receive(:current_phase){ 'canceled' }
      end
      it 'returns true' do
        expect(@workflow.canceled?).to be_truthy
      end
    end
    context 'when not canceled' do
      before do
        expect(@workflow).to receive(:current_phase){ 'start' }
      end
      it 'returns false' do
        expect(@workflow.canceled?).to be_falsey
      end
    end
  end
  describe '#running?' do
    before do
      @workflow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when paused' do
      before do
        expect(@workflow).to receive(:paused?){ true }
      end
      it 'returns false' do
        expect(@workflow.running?).to be_falsey
      end
    end
    context 'when canceled' do
      before do
        expect(@workflow).to receive(:paused?){ false }
        expect(@workflow).to receive(:canceled?){ true }
      end
      it 'returns false' do
        expect(@workflow.running?).to be_falsey
      end
    end
    context 'when finished' do
      before do
        expect(@workflow).to receive(:paused?){ false }
        expect(@workflow).to receive(:canceled?){ false }
        expect(@workflow).to receive(:finished?){ true }
      end
      it 'returns false' do
        expect(@workflow.running?).to be_falsey
      end
    end
    context 'when neither canceled, paused nor finished' do
      before do
        expect(@workflow).to receive(:paused?){ false }
        expect(@workflow).to receive(:canceled?){ false }
        expect(@workflow).to receive(:finished?){ false }
      end
      it 'returns true' do
        expect(@workflow.running?).to be_truthy
      end
    end
  end

  describe '#finished?' do
    before do
      @workflow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when the latest transition is to a phase that' do
      before do
        expect(@workflow).to receive(:transitions) do
          [OpenStruct.new( to: 'latest-phase' )]
        end
        expect(@workflow).to receive(:phase) do
          phase = double('phase')
          expect(phase).to receive(:is_final){ @is_final }
          phase
        end
      end
      context 'is final' do
        before do
          @is_final = true
        end
        it 'returns true' do
          expect(@workflow.finished?).to be_truthy
        end
      end
      context 'is not final' do
        before do
          @is_final = false
        end
        it 'returns false' do
          expect(@workflow.finished?).to be_falsey
        end
      end
    end
  end

  describe '#add_transition(...)' do
    before do
      @workflow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    before do
      @transition_info = {
        from: 'start',
        to: 'finish',
        timestamp: Time.now.utc.to_f
      }
      redis = double('redis')
      expect(redis).to receive(:sadd).with(@workflow.redis_id + ":transitions", @transition_info.to_json)
      expect(@workflow).to receive(:redis){ redis }
    end
    it 'adds a transition record for the workflow' do
      @workflow.add_transition(@transition_info)
    end
  end

  describe '#transitions' do
    before do
      @workflow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
      redis = double('redis')
      expect(redis).to receive(:smembers).with(@workflow.redis_id + ':transitions'){ @transitions }
      expect(@workflow).to receive(:redis){ redis }
    end
    context 'when there are no transitions yet' do
      before do
        @transitions = [ ]
      end
      it 'returns an empty list' do
        expect(@workflow.transitions).to eq [ ]
      end
    end
    context 'when there are transitions' do
      before do
        @transitions = [
          {from: 'paused', to: 'start', timestamp: 20.seconds.ago.to_f},
          {from: nil, to: 'start', timestamp: 60.seconds.ago.to_f},
          {from: 'start', to: 'paused', timestamp: 40.seconds.ago.to_f},
        ].map(&:to_json)
      end
      it 'returns them sorted by timestamp' do
        original_transitions = @transitions.map{|x| JSON.parse(x, symbolize_names: true)}
        @results = @workflow.transitions
        expect(@results.first.timestamp).to eq original_transitions[1][:timestamp]
        expect(@results.last.timestamp).to eq original_transitions.first[:timestamp]
      end
    end
  end

  describe '#redis' do
    it 'returns redis' do
      expect(Distribot::Workflow).to receive(:redis){ 'redis-lol' }
      expect(described_class.new.send(:redis)).to eq 'redis-lol'
    end
  end

  describe '.redis' do
    it 'returns redis' do
      expect(Distribot).to receive(:redis){ 'redis-lol' }
      expect(described_class.send(:redis)).to eq 'redis-lol'
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

