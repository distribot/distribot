
module Distribot

  class HandlerRunner
    include Distribot::Handler
    @@consumers = [ ]
    subscribe_to 'distribot.workflow.handler.start', handler: :callback

    def callback(message)
      finished_queue = message[:queue_name] + '.finished'
      workflow_id, phase = /distribot\.workflow\.(?<workflow_id>.+?)\.(?<phase>.+?)\./.match( message[:queue_name] ).captures
      context = OpenStruct.new(message.merge(phase: phase, workflow_id: workflow_id))
      @@consumers << Distribot.queue(message[:queue_name]).subscribe do |_, _, payload|
        task = JSON.parse(payload, symbolize_names: true)
        Thread.new do
          Kernel.const_get(message[:handler]).perform(context, task) do
            # Announce this task as finished:
            Distribot.publish! finished_queue, {foo: :bar}.to_json
          end
        end
      end
    end

    def self.add_consumer(consumer)
      @@consumers << consumer
    end

    def self.cancel_consumers_for(queue_name)
      @@consumers.select{|consumer| consumer.queue.name == queue_name}.map{|consumer| puts "Cancelling consumer of #{consumer.queue.name}".upcase; consumer}.map(&:cancel)
      @@consumers = @@consumers.delete_if{|x| x.queue.name == queue_name}
    end
  end

end
