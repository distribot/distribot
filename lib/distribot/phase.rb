
module Distribot
  class Phase
    attr_accessor :id,
                  :name,
                  :is_initial,
                  :is_final,
                  :transitions_to,
                  :on_error_transition_to,
                  :handlers

    def initialize(name, attrs={})
      attrs.each do |key,val|
        self.send("#{key}=", val)
      end
      self.name = name
    end

  end
end
