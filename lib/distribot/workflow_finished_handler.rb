
module Distribot
  class WorkflowFinishedHandler
    @@total = 0
    @@max = ENV["MAX_WORKFLOWS"].to_i > 0 ? ENV["MAX_WORKFLOWS"].to_i : 10
    include Distribot::Handler
    subscribe_to 'distribot.workflow.finished', handler: :callback

    def callback(message)
      workflow = Distribot::Workflow.find(message[:workflow_id])
puts ">>>>>>>>>>>>>>>>>>>> WORKFLOW #{workflow.name} FINISHED!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      if Distribot.queue_exists?("distribot.workflow.#{workflow.id}.finished")
        Distribot.publish! "distribot.workflow.#{workflow.id}.finished", {
          workflow_id: workflow.id
        }
      end
      # TODO: mark this workflow as 'finished'
      # Maybe via Sidekiq.
      if ENV.has_key? 'MAX_WORKFLOWS'
        if @@total < @@max
          Distribot::Workflow.create!(workflow.send(:to_hash).except(:id).merge(name: "Workflow ##{@@total + 1}"))
          Distribot::Workflow.create!(workflow.send(:to_hash).except(:id).merge(name: "Workflow ##{@@total + 2}"))
          @@total += 2
        end
      end
    end
  end
end
