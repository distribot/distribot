
module Distribot
  class Phase
    attr_accessor :id,
                  :name,
                  :is_initial,
                  :is_final,
                  :transitions_to,
                  :on_error_transition_to,
                  :handlers

    def initialize(attrs = {})
      attrs.each do |key, val|
        next if key.to_s == 'handlers'
        public_send("#{key}=", val)
      end
      self.name = name
      self.handlers = []
      initialize_handlers(attrs[:handlers] || [])
    end

    def to_hash
      {
        id: id,
        name: name,
        is_initial: is_initial || false,
        is_final: is_final || false,
        transitions_to: transitions_to,
        on_error_transition_to: on_error_transition_to,
        handlers: handlers
      }
    end

    private

    def initialize_handlers(handler_args)
      handler_args.each do |handler|
        if handler.is_a? Hash
          handlers.push(PhaseHandler.new handler)
        else
          handlers.push(PhaseHandler.new name: handler)
        end
      end
    end
  end
end
