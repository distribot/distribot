
module Distribot
  class Workflow
    attr_accessor :name, :phases

    def initialize(attrs={})
      self.name = attrs[:name]
      self.phases = [ ]
      if attrs.has_key? :phases
        attrs[:phases].each do |name, options|
          self.add_phase(name, options)
        end
      end
    end

    def add_phase(name, options={})
      self.phases << Phase.new(name, options)
    end
  end
end
