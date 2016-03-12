require 'spec_helper'

describe Distribot::Flow do
  before do
    @json = JSON.parse( File.read('spec/fixtures/simple_flow.json'), symbolize_names: true )
  end
  it 'can be initialized' do
    flow = Distribot::Flow.new(
      phases: @json[:phases],
      data: {
        foo: :bar,
        items: [ {item1: 'Hello', item2: 'World'} ]
      }
    )
    expect(flow.phases.count).to eq @json[:phases].count
    expect(flow.data[:foo]).to eq :bar
  end

  describe '.active' do
    context 'when there are' do
      context 'no active flows' do
        before do
          redis = double('redis')
          expect(redis).to receive(:smembers).with('distribot.flows.active'){ [] }
          expect(Distribot::Flow).to receive(:redis){ redis }
        end
        it 'returns an empty list' do
          expect(Distribot::Flow.active).to eq []
        end
      end
      context 'some active flows' do
        before do
          @flow_ids = ['foo', 'bar']
          redis = double('redis')
          expect(redis).to receive(:smembers).with('distribot.flows.active'){ @flow_ids }
          @flow_ids.each do |id|
            expect(redis).to receive(:get).with("distribot-flow:#{id}:definition") do
              {
                id: id,
                phases: [ ]
              }.to_json
            end
          end
          expect(Distribot::Flow).to receive(:redis).exactly(3).times{ redis }
        end
        it 'returns them' do
          flows = Distribot::Flow.active
          expect(flows).to be_an Array
          expect(flows.map(&:id)).to eq @flow_ids
        end
      end
    end
  end

  describe '#redis_id' do
    before do
      @flow = Distribot::Flow.new(
        id: 'fake-id'
      )
    end
    it 'returns the redis id' do
      expect(@flow.redis_id).to eq 'distribot-flow:' + 'fake-id'
    end
  end

  describe '#save!' do
    before do
      @flow = Distribot::Flow.new(
        phases: @json[:phases]
      )
    end
    context 'when saving' do
      context 'fails' do
        context 'because the flow already has an id' do
          before do
            @flow.id = 'some-id'
          end
          it 'raises an error' do
            expect{@flow.save!}.to raise_error StandardError
          end
        end
      end
      context 'succeeds' do
        before do
          # Fake id:
          expect(SecureRandom).to receive(:uuid){ 'xxx' }

          # Redis-saving:
          redis = double('redis')
          expect(redis).to receive(:set).with('distribot-flow:xxx:definition', anything)
          expect(redis).to receive(:sadd).with('distribot.flows.active', 'xxx')
          expect(redis).to receive(:incr).with('distribot.flows.running')
          expect(@flow).to receive(:redis).exactly(3).times{ redis }

          # Transition-making:
          expect(@flow).to receive(:current_phase){ 'start' }
          expect(@flow).to receive(:add_transition).with(hash_including(to: 'start'))

          # Announcement-publishing:
          expect(Distribot).to receive(:publish!).with('distribot.flow.created', {
            flow_id: 'xxx'
          })
        end
        context 'when a callback is provided' do
          before do
            expect(Thread).to receive(:new) do |&block|
              block.call
            end
            expect(@flow).to receive(:finished?).ordered{false}
            expect(@flow).to receive(:canceled?).ordered{false}
            expect(@flow).to receive(:finished?).ordered{true}
          end
          it 'waits until finished, then calls the callback with {flow_id: self.id}' do
            @callback_args = nil
            @flow.save! do |info|
              @callback_args = info
            end
            expect(@callback_args).to eq(flow_id: 'xxx')
          end
        end
        context 'when no callback is provided' do
          it 'saves it in redis' do
            @flow.save!
          end
        end
      end
    end
  end

  describe '.create!' do
    before do
      expect_any_instance_of(Distribot::Flow).to receive(:save!)
    end
    it 'saves the object' do
      flow = Distribot::Flow.create!(phases: [ ])
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
      it 'returns the correct flow' do
        expect(described_class.find('any-id')).to be_a described_class
      end
      context 'the data' do
        before do
          @flow = described_class.find('any-id')
        end
        it 'is intact' do
          expect(@flow.data[:flow_info]).to eq(foo: 'bar')
        end
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
      @flow = Distribot::Flow.new(
        id: 'xxx',
        phases: [{is_initial: true, name: 'testy'} ]
      )
    end
    context 'when the phase' do
      context 'exists' do
        it 'returns the phase object' do
          expect(@flow.phase('testy')).to be_a Distribot::Phase
        end
      end
      context 'does not exist' do
        it 'returns nil' do
          expect(@flow.phase('missing-phase')).to be_nil
        end
      end
    end
  end

  describe '#transition_to!(:phase_name)' do
    context 'when the flow' do
      before do
        @flow = Distribot::Flow.new(
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
          expect(@flow).to receive(:transitions){ [ ] }
          expect(Distribot).to receive(:publish!).with('distribot.flow.phase.started', {
            flow_id: @flow.id,
            phase: @next_phase
          })
        end
        it 'stores a transition from nil to the new phase' do
          expect(@flow).to receive(:add_transition).with(hash_including(from: nil, to: @next_phase))
          @flow.transition_to!(@next_phase)
        end
      end
      context 'had a previous phase' do
        before do
          @next_phase = 'finish'
          expect(@flow).to receive(:transitions) do
            [
              {from: nil, to: 'start'}
            ]
          end
          expect(Distribot).to receive(:publish!).with('distribot.flow.phase.started', {
            flow_id: @flow.id,
            phase: @next_phase
          })
        end
        it 'stores a transition from the previous phase to the new phase' do
          expect(@flow).to receive(:add_transition).with(hash_including(from: 'start', to: @next_phase))
          @flow.transition_to!(@next_phase)
        end
      end
    end
  end

  describe '#current_phase' do
    before do
      @flow = Distribot::Flow.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when the flow' do
      context 'has previous transitions' do
        before do
          expect(@flow).to receive(:transitions) do
            [
              OpenStruct.new(from: nil,     to: 'start',  timestamp: 60.seconds.ago.to_i ),
              OpenStruct.new(from: 'start', to: 'finish', timestamp: 30.seconds.ago.to_i )
            ]
          end
        end
        it 'returns the "to" value of the latest transition' do
          expect(@flow.current_phase).to eq 'finish'
        end
      end
      context 'has no previous transitions' do
        before do
          expect(@flow).to receive(:transitions){ [ ] }
        end
        it 'returns the first is_initial:true phase name' do
          expect(@flow.current_phase).to eq 'start'
        end
      end
    end
  end

  describe '#next_phase' do
    before do
      @flow = Distribot::Flow.new(
        id: 'xxx',
        phases: [
          {name: 'step1', is_initial: true, transitions_to: 'step2'},
          {name: 'step2', is_final: true},
        ]
      )
    end
    context 'when there is a next phase' do
      before do
        expect(@flow).to receive(:current_phase){ 'step1' }
      end
      it 'returns the next phase name' do
        expect(@flow.next_phase).to eq 'step2'
      end
    end
    context 'when there is no next phase' do
      before do
        expect(@flow).to receive(:current_phase){ 'step2' }
      end
      it 'returns nil' do
        expect(@flow.next_phase).to be_nil
      end
    end
  end

  describe '#pause!' do
    before do
      @flow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when running' do
      before do
        expect(@flow).to receive(:running?){ true }
        expect(@flow).to receive(:current_phase){ 'start' }
        expect(@flow).to receive(:add_transition).with(hash_including(
          from: 'start',
          to: 'paused'
        ))
      end
      it 'pauses' do
        @flow.pause!
      end
    end
    context 'when not running' do
      before do
        expect(@flow).to receive(:running?){ false }
        expect(@flow).not_to receive(:current_phase)
        expect(@flow).not_to receive(:add_transition)
      end
      it 'raises an exception' do
        expect{@flow.pause!}.to raise_error Distribot::NotRunningError
      end
    end
  end
  describe '#paused?' do
    before do
      @flow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when paused' do
      before do
        expect(@flow).to receive(:current_phase){ 'paused' }
      end
      it 'returns true' do
        expect(@flow.paused?).to be_truthy
      end
    end
    context 'when not paused' do
      before do
        expect(@flow).to receive(:current_phase){ 'start' }
      end
      it 'returns false' do
        expect(@flow.paused?).to be_falsey
      end
    end
  end
  describe '#resume!' do
    before do
      @flow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when paused' do
      before do
        expect(@flow).to receive(:paused?){ true }
        expect(@flow).to receive(:transitions) do
          to_start = {from: nil, to: 'start', timestamp: 60.seconds.ago.to_f}
          to_paused = {from: 'start', to: 'paused', timestamp: 30.seconds.ago.to_f}
          [to_start, to_paused].map{|x| OpenStruct.new x }
        end
        expect(@flow).to receive(:add_transition).with(hash_including(
          from: 'paused',
          to: 'start'
        ))
      end
      it 'transitions back to the last phase transitioned to' do
        @flow.resume!
      end
    end
    context 'when not paused' do
      before do
        expect(@flow).to receive(:paused?){ false }
      end
      it 'raises an exception' do
        expect{@flow.resume!}.to raise_error Distribot::NotPausedError
      end
    end
  end
  describe '#cancel!' do
    before do
      @flow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when running' do
      before do
        expect(@flow).to receive(:running?){ true }
        expect(@flow).to receive(:current_phase){ 'start' }
        expect(@flow).to receive(:add_transition).with(hash_including(
          from: 'start',
          to: 'canceled'
        ))
        redis = double('redis')
        expect(@flow).to receive(:redis).exactly(2).times{ redis }
        expect(redis).to receive(:srem).with('distribot.flows.active', @flow.id)
        expect(redis).to receive(:decr).with('distribot.flows.running')
      end
      it 'cancels the flow' do
        @flow.cancel!
      end
    end
    context 'when not running' do
      before do
        expect(@flow).to receive(:running?){ false }
        expect(@flow).not_to receive(:current_phase)
        expect(@flow).not_to receive(:add_transition)
      end
      it 'raises an exception' do
        expect{@flow.cancel!}.to raise_error Distribot::NotRunningError
      end
    end
  end
  describe '#canceled?' do
    before do
      @flow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when canceled' do
      before do
        expect(@flow).to receive(:current_phase){ 'canceled' }
      end
      it 'returns true' do
        expect(@flow.canceled?).to be_truthy
      end
    end
    context 'when not canceled' do
      before do
        expect(@flow).to receive(:current_phase){ 'start' }
      end
      it 'returns false' do
        expect(@flow.canceled?).to be_falsey
      end
    end
  end
  describe '#running?' do
    before do
      @flow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when paused' do
      before do
        expect(@flow).to receive(:paused?){ true }
      end
      it 'returns false' do
        expect(@flow.running?).to be_falsey
      end
    end
    context 'when canceled' do
      before do
        expect(@flow).to receive(:paused?){ false }
        expect(@flow).to receive(:canceled?){ true }
      end
      it 'returns false' do
        expect(@flow.running?).to be_falsey
      end
    end
    context 'when finished' do
      before do
        expect(@flow).to receive(:paused?){ false }
        expect(@flow).to receive(:canceled?){ false }
        expect(@flow).to receive(:finished?){ true }
      end
      it 'returns false' do
        expect(@flow.running?).to be_falsey
      end
    end
    context 'when neither canceled, paused nor finished' do
      before do
        expect(@flow).to receive(:paused?){ false }
        expect(@flow).to receive(:canceled?){ false }
        expect(@flow).to receive(:finished?){ false }
      end
      it 'returns true' do
        expect(@flow.running?).to be_truthy
      end
    end
  end

  describe '#finished?' do
    before do
      @flow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
    end
    context 'when the latest transition is to a phase that' do
      before do
        expect(@flow).to receive(:transitions) do
          [OpenStruct.new( to: 'latest-phase' )]
        end
        expect(@flow).to receive(:phase) do
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
          expect(@flow.finished?).to be_truthy
        end
      end
      context 'is not final' do
        before do
          @is_final = false
        end
        it 'returns false' do
          expect(@flow.finished?).to be_falsey
        end
      end
    end
  end

  describe '#add_transition(...)' do
    before do
      @flow = described_class.new(
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
      expect(redis).to receive(:sadd).with(@flow.redis_id + ":transitions", @transition_info.to_json)
      expect(@flow).to receive(:redis){ redis }
    end
    it 'adds a transition record for the flow' do
      @flow.add_transition(@transition_info)
    end
  end

  describe '#transitions' do
    before do
      @flow = described_class.new(
        id: 'xxx',
        phases: [
          {name: 'start', is_initial: true},
          {name: 'finish', is_final: true},
        ]
      )
      redis = double('redis')
      expect(redis).to receive(:smembers).with(@flow.redis_id + ':transitions'){ @transitions }
      expect(@flow).to receive(:redis){ redis }
    end
    context 'when there are no transitions yet' do
      before do
        @transitions = [ ]
      end
      it 'returns an empty list' do
        expect(@flow.transitions).to eq [ ]
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
        @results = @flow.transitions
        expect(@results.first.timestamp).to eq original_transitions[1][:timestamp]
        expect(@results.last.timestamp).to eq original_transitions.first[:timestamp]
      end
    end
  end

  describe '#redis' do
    it 'returns redis' do
      expect(Distribot::Flow).to receive(:redis){ 'redis-lol' }
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
          flow = described_class.new
          @max_tries = 3
          @total_tries = 0
          expect(flow).to receive(:warn).exactly(3).times
          expect(flow.stubbornly(:foo){
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
          flow = described_class.new
          expect(flow.stubbornly(:foo){ @return_value }).to eq @return_value
        end
      end
    end
  end
end

