
module Distribot

  class HandlerRunner
    include Distribot::Handler
    @@consumers = [ ]
    subscribe_to 'distribot.workflow.handler.started', handler: :callback

    def callback(message)
pp message: message
#byebug
      workflow = Distribot::Workflow.find( message[:workflow_id] )
      phase = workflow.phase( workflow.current_phase )
      queue_counts = phase.handlers.map do |handler|
        queue_name = "distribot.workflow.#{workflow.id}.#{phase.name}.#{handler}.tasks"
        # Insert these jobs into the handler's queue:
        job_count = 0
        context = OpenStruct.new(phase: phase.name, workflow_id: workflow.id)
        Kernel.const_get(handler).enumerate_jobs(context, workflow) do |jobs|
          Distribot.redis.incrby queue_name, jobs.count
puts "INCREMENTED '#{queue_name}' by #{jobs.count}"
          jobs.each{|job| Distribot.publish! queue_name, job.to_json }
        end
        { queue_name: queue_name, handler: handler }
      end

      queue_counts.each do |message|
puts "Phase Enqueued! #{phase.name}"
        Distribot.broadcast! 'distribot.workflow.phase.enqueued', message.merge(workflow_id: workflow.id).to_json
      end

      finished_queue = message[:queue_name] + '.finished'
      workflow_id, phase = /distribot\.workflow\.(?<workflow_id>.+?)\.(?<phase>.+?)\./.match( message[:queue_name] ).captures
      context = OpenStruct.new(message.merge(phase: phase, workflow_id: workflow_id))
      @@consumers << Distribot.queue(message[:queue_name]).subscribe do |_, _, payload|
pp finished: finished_queue
        task = JSON.parse(payload, symbolize_names: true)
        Thread.new do
          Kernel.const_get(message[:handler]).perform(context, task) do
            # Announce this task as finished:
            Distribot.broadcast! finished_queue, {foo: :bar}.to_json
          end
        end
      end
    end

    def self.add_consumer(consumer)
      @@consumers << consumer
    end

    def self.cancel_consumers_for(queue_name)
      @@consumers.select{|consumer| consumer.queue.name == queue_name}.map do |consumer|
        puts "Cancelling consumer of #{consumer.queue.name}".upcase
        consumer
      end.map(&:cancel)
      @@consumers = @@consumers.delete_if{|x| x.queue.name == queue_name}
    end
  end

end
