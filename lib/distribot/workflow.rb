
module Distribot
  class Workflow
    attr_accessor :id, :name, :phases, :consumer, :finished_callback_queue

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

    def validate!
      # Make sure the phases make a continuous line:
      self.phases.each do |phase|
        next if phase.is_final
        unless (self.phases.map{|x| x.name } - [phase.name]).include? phase.transitions_to
          raise "Phase '#{phase.name}' transitions to invalid phase '#{phase.transitions_to}'"
        end
        # Make sure every handler is actively watched:
        phase.handlers.each do |handler|
          queue_names = [
            "distribot.workflow.handler.#{handler}.enumerate",
            "distribot.workflow.handler.#{handler}.tasks",
          ]
          queue_names.each do |queue_name|
            unless Distribot.queue_exists?(queue_name)
              raise "The worker queue '#{queue_name}' for handler '#{handler}' does not yet exist. Make sure the handler is active within a worker."
            end
          end
        end
      end

      # Make sure the engine appears to be running:
      engine_queues = %w(
        distribot.workflow.created
        distribot.workflow.phase.started
        distribot.workflow.task.finished
        distribot.workflow.handler.finished
        distribot.workflow.phase.finished
        distribot.workflow.finished
      )
      missing_queues = engine_queues.reject{|queue| Distribot.queue_exists?(queue) }
      unless missing_queues.empty?
        raise "The following engine queues are missing. Ensure their workers are enabled. #{missing_queues.join(", ")}"
      end

      # Finally:
      true
    end

    def self.create!(attrs={})
      obj = self.new(attrs)
      obj.save!
      return obj
    end

    def save!(&block)
      self.id = SecureRandom.uuid
      record_id = self.redis_id + ':definition'
      is_new = redis.get(record_id).to_s == ''
      redis.set record_id, serialize
      redis.sadd 'distribot.workflows.active', self.id

      if is_new
        self.add_transition( :to => self.current_phase, :timestamp => Time.now.utc.to_f )
        Distribot.publish! 'distribot.workflow.created', {
          workflow_id: self.id
        }
        if block_given?
          Thread.new do
            while true do
              sleep 1
              if self.finished?
                block.call( workflow_id: self.id )
                break
              end
            end
          end
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
      while true do
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
