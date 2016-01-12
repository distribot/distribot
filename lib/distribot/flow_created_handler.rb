
module Distribot
  class FlowCreatedHandler
    include Distribot::Handler
    subscribe_to 'distribot.flow.created', handler: :callback

    def callback(message)
      flow = Distribot::Flow.find(message[:flow_id])
      flow.transition_to! flow.next_phase
    end
  end
end
