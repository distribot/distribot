
module Distribot
  class FlowFinishedHandler
    include Distribot::Handler
    subscribe_to 'distribot.flow.finished', handler: :callback

    def callback(message)
      Distribot.redis.decr('distribot.flows.running')
      Distribot.redis.srem 'distribot.flows.active', message[:flow_id]
    end
  end
end
