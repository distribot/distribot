
module Distribot
  class PhaseHandler
    attr_accessor :name, :version
    def initialize(attrs = {})
      attrs.each do |key, val|
        public_send("#{key}=", val)
      end
    end

    def to_s
      name
    end
  end
end
