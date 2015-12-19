
module Distribot

  require 'semantic'

  class PhaseStartedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.phase.started', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find( message[:workflow_id] )
      phase = workflow.phase(message[:phase])
      if phase.handlers.empty?
        Distribot.publish! 'distribot.workflow.phase.finished', {
          workflow_id: workflow.id,
          phase: phase.name
        }
      else
        phase.handlers.each do |handler|
          jumpstart_handler(workflow, phase, handler)
        end
      end
    end

    def jumpstart_handler(workflow, phase, handler)
      worker_version = if handler.version
        wanted_version = Gem::Dependency.new(handler.to_s, handler.version)
        # Figure out the highest acceptable version of the handler we can assign work to:
        self.handler_versions(handler.to_s)
          .reverse
          .find{|x| wanted_version.match?(handler.to_s, x.to_s) }
          .to_s
      else
        # Find the highest version for this queue:
        self.handler_versions(handler.to_s).last
      end
      raise "Cannot find suitable #{handler} version #{handler.version}" unless worker_version

      enumerate_queue = "distribot.workflow.handler.#{handler}.#{worker_version}.enumerate"
      task_queue = "distribot.workflow.handler.#{handler}.#{worker_version}.tasks"
      finished_queue = "distribot.workflow.task.finished"
      task_counter = "distribot.workflow.#{workflow.id}.#{phase.name}.#{handler}.finished"

      Distribot.publish! enumerate_queue, {
        workflow_id: workflow.id,
        phase: phase.name,
        task_queue: task_queue,
        task_counter: task_counter,
        finished_queue: finished_queue
      }
    end

    def handler_versions(handler)
      queue_prefix = "distribot.workflow.handler.#{handler}."
      Distribot.connector.queues
        .select{|x| x.start_with? queue_prefix }
        .reject{|x| x.end_with? '.enumerate' }
        .map{|x| x.gsub(/^#{queue_prefix}/, '').gsub(/\.tasks$/,'') }
        .map{|x| Semantic::Version.new x }
        .sort
    end
  end

end
