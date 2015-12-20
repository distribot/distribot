
module Distribot
  require 'semantic'
  class PhaseStartedHandler
    include Distribot::Handler
    subscribe_to 'distribot.workflow.phase.started', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
      phase = workflow.phase(message[:phase])
      if phase.handlers.empty?
        Distribot.publish!(
          'distribot.workflow.phase.finished',
          workflow_id: workflow.id,
          phase: phase.name
        )
      else
        handler_versions = phase.handlers.map do |handler|
          version = best_version(handler)
          unless version && !version.blank?
            fail "Cannot find a good #{handler} version #{handler.version}"
          end
          {
            handler.to_s => version
          }
        end.reduce({}, :merge)
        phase.handlers.each do |handler|
          init_handler(workflow, phase, handler, handler_versions[handler.to_s])
        end
      end
    end

    # rubocop:disable Metrics/LineLength
    def init_handler(workflow, phase, handler, version)
      Distribot.publish!(
        "distribot.workflow.handler.#{handler}.#{version}.enumerate",
        workflow_id: workflow.id,
        phase: phase.name,
        task_queue: "distribot.workflow.handler.#{handler}.#{version}.tasks",
        task_counter: "distribot.workflow.#{workflow.id}.#{phase.name}.#{handler}.finished",
        finished_queue: 'distribot.workflow.task.finished'
      )
    end

    def best_version(handler)
      if handler.version
        wanted_version = Gem::Dependency.new(handler.to_s, handler.version)
        # Figure out the highest acceptable version of the handler we can assign work to:
        handler_versions(handler.to_s)
          .reverse
          .find { |x| wanted_version.match?(handler.to_s, x.to_s) }
          .to_s
      else
        # Find the highest version for this queue:
        handler_versions(handler.to_s).last
      end
    end

    def handler_versions(handler)
      queue_prefix = "distribot.workflow.handler.#{handler}."
      Distribot.connector.queues
        .select { |x| x.start_with? queue_prefix }
        .reject { |x| x.end_with? '.enumerate' }
        .map { |x| x.gsub(/^#{queue_prefix}/, '').gsub(/\.tasks$/, '') }
        .map { |x| Semantic::Version.new x }
        .sort
    end
  end
end
