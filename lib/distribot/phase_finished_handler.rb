
module Distribot
  class PhaseFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.flow.phase.finished', handler: :callback

    def callback(message)
      flow = Distribot::Flow.find(message[:flow_id])
      return unless flow.current_phase == message[:phase]
      if flow.next_phase
        flow.transition_to! flow.next_phase
      else
        Distribot.publish!(
          'distribot.flow.finished', flow_id: flow.id
        )
      end
    end
  end
end
