
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
          # wanted_version = '~> 1.0.1'
          # handler_version = Gem::Dependency.new('', wanted_version)
          # # Figure out the highest acceptable version of the handler we can assign work to:
          # queue_prefix = "distribot.workflow.handler.#{handler}."
          # worker_version = Distribot.connector.queues
          #                   .select{|x| x.start_with? queue_prefix }
          #                   .reject{|x| x.end_with? '.enumerate' }
          #                   .map{|x| x.gsub(/^#{queue_prefix}/, '').gsub(/\.tasks$/,'') }
          #                   .map{|x| Semantic::Version.new x }
          #                   .reject{|x| x.major != handler_version.major }
          #                   .sort
          #                   .reverse
          #                   .select{|x| handler_version.match?(nil, handler_version.to_s) }
          #                   .first
          #                   .to_s
#          raise "Cannot find suitable #{handler} version #{wanted_version}" unless worker_version

#          enumerate_queue = "distribot.workflow.handler.#{handler}.#{worker_version}.enumerate"
#          task_queue = "distribot.workflow.handler.#{handler}.#{worker_version}.tasks"
          enumerate_queue = "distribot.workflow.handler.#{handler}.enumerate"
          task_queue = "distribot.workflow.handler.#{handler}.tasks"
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
      end
    end
  end

end
