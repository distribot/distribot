
module Distribot
  class NotRunningError < StandardError; end
  class NotPausedError < StandardError; end

  class Workflow
    attr_accessor :id, :phases, :consumer, :finished_callback_queue, :created_at

    def initialize(attrs={})
      self.id = attrs[:id]
      self.created_at = attrs[:created_at] unless attrs[:created_at].nil?
      self.phases = [ ]
      if attrs.has_key? :phases
        attrs[:phases].each do |options|
          self.add_phase(options)
        end
      end
    end

    def self.create!(attrs={})
      obj = self.new(attrs)
      obj.save!
      return obj
    end

    def save!(&block)
      raise StandardError.new('Cannot re-save a workflow') if self.id
      self.id = SecureRandom.uuid
      record_id = self.redis_id + ':definition'
      self.created_at = Time.now.to_f

      # Actually save the record:
      redis.set record_id, serialize

      # Transition into the first phase:
      self.add_transition( :to => self.current_phase, :timestamp => Time.now.utc.to_f )

      # Add our id to the list of active workflows:
      redis.sadd 'distribot.workflows.active', self.id

      # Announce our arrival to the rest of the system:
      Distribot.publish! 'distribot.workflow.created', {
        workflow_id: self.id
      }

      if block_given?
        Thread.new do
          loop do
            sleep 1
            if self.finished?
              block.call( workflow_id: self.id )
              break
            end
          end
        end
      end
    end

    def self.find(id)
      redis_id = Distribot.redis_id("workflow", id)
      raw_json = redis.get( "#{redis_id}:definition" ) or return
      self.new(
        JSON.parse( raw_json, symbolize_names: true )
      )
    end

    def add_phase(options={})
      self.phases << Phase.new(options)
    end

    def phase(name)
      self.phases.find{|x| x.name == name}
    end

    def pause!
      raise NotRunningError.new "Cannot pause unless running" unless self.running?
      self.add_transition(
        from: self.current_phase,
        to: 'paused',
        timestamp: Time.now.utc.to_f
      )
    end

    def resume!
      raise NotPausedError.new "Cannot resume unless paused" unless self.paused?

      # Find the last transition before we were paused:
      prev_phase = self.transitions.reverse.find{|x| x.to != 'paused'}
      # Back to where we once belonged
      self.add_transition(from: 'paused', to: prev_phase.to, timestamp: Time.now.utc.to_f)
    end

    def paused?
      self.current_phase == 'paused'
    end

    def cancel!
      raise NotRunningError.new "Cannot cancel unless running" unless self.running?
      self.add_transition(from: self.current_phase, to: 'canceled', timestamp: Time.now.utc.to_f)
    end

    def canceled?
      self.current_phase == 'canceled'
    end

    def running?
      ! ( self.paused? || self.canceled? || self.finished? )
    end

    def redis_id
      @redis_id ||= Distribot.redis_id("workflow", self.id)
    end

    def transition_to!(phase)
      previous_transition = self.transitions.last
      prev = previous_transition ? previous_transition[:to] : nil
      self.add_transition( from: prev, to: phase, timestamp: Time.now.utc.to_f )
      Distribot.publish! 'distribot.workflow.phase.started', {
        workflow_id: self.id,
        phase: phase
      }
    end

    def add_transition(item)
      redis.sadd(self.redis_id + ':transitions', item.to_json)
    end

    def transitions
      redis.smembers(self.redis_id + ':transitions').map do |item|
        OpenStruct.new JSON.parse(item, symbolize_names: true)
      end.sort_by(&:timestamp)
    end

    def current_phase
      ( self.transitions.sort_by(&:timestamp).last.to rescue nil ) || self.phases.find{|x| x.is_initial }.name
    end

    def next_phase
      current = self.current_phase
      self.phases.find{|x| x.name == current }.transitions_to
    end

    def finished?
      self.phase( self.transitions.last.to ).is_final
    end

    def stubbornly task, &block
      result = nil
      loop do
        begin
          result = block.call
          break
        rescue NoMethodError => e
          warn "Error during #{task}: #{e} --- #{e.backtrace.join("\n")}"
          sleep 1
          next
        end
      end
      result
    end

    private

    def self.redis
      Distribot.redis
    end

    def redis
      self.class.redis
    end

    def serialize
      to_hash.to_json
    end

    def to_hash
      {
        id: self.id,
        created_at: self.created_at,
        phases: self.phases.map(&:to_hash)
      }
    end
  end
end
