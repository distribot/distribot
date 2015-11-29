
module Distribot
  class Workflow
    attr_accessor :id, :name, :phases

    def initialize(attrs={})
      self.id = attrs[:id]
      self.name = attrs[:name]
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
      self.id ||= SecureRandom.uuid
      record_id = self.redis_id + ':definition'
      is_new = redis.keys(record_id).count <= 0
      redis.set record_id, serialize

      Distribot.publish! 'distribot.workflow.created', {
        workflow_id: self.id
      }
      if is_new
        self.add_transition( :to => self.current_phase, :timestamp => Time.now.utc.to_f )
        if block_given?
          finished_id = "distribot.workflow.#{self.id}.finished"
          @consumer = Distribot.subscribe(finished_id) do |message|
            Distribot.redis.set(finished_id, message.to_json)
          end
          while true do
            sleep 1
            payload = Distribot.redis.get(finished_id)
            unless payload.nil?
              @consumer.cancel
              Distribot.redis.del(finished_id)
              break
            end
          end
          block.call(payload)
        end
      end
    end

    def self.find(id)
      redis_id = Distribot.redis_id("workflow", id)
      raw_json = Distribot.redis.get( "#{redis_id}:definition" ) or return
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
      end
    end

    def current_phase
      ( self.transitions.sort_by(&:timestamp).last.to rescue nil ) || self.phases.find{|x| x.is_initial }.name
    end

    def next_phase
      current = self.current_phase
      self.phases.find{|x| x.name == current }.transitions_to
    end

    private

    def redis
      Distribot.redis
    end

    def serialize
      to_hash.to_json
    end

    def to_hash
      {
        id: self.id,
        name: self.name,
        phases: self.phases.map(&:to_hash)
      }
    end
  end
end
