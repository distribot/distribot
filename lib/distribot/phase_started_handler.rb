
module Distribot

  class PhaseStartedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.phase.started', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find( message[:workflow_id] )
      phase = workflow.phase( workflow.current_phase )

      if phase.handlers.empty?
        Distribot.publish! 'distribot.workflow.phase.finished', {
          workflow_id: workflow.id,
          phase: phase.name
        }.to_json
      else
        queue_counts = phase.handlers.map do |handler|

          queue_name = "distribot.workflow.#{workflow.id}.#{phase.name}.#{handler}.tasks"

          # Announce that we need some workers to listen to the task queue:
          Distribot.publish! 'distribot.workflow.handler.start', {
            handler: handler,
            queue_name: queue_name
          }.to_json

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
          Distribot.publish! 'distribot.workflow.phase.enqueued', message.merge(workflow_id: workflow.id).to_json
        end
      end
    end
  end

end
