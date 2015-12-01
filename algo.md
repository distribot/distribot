

## Engine Nodes

subscribe: distribot.workflow.created(:workflow_id)
  * on receive:
    1. workflow.transition_to( :next_phase )
    2. publish: distribot.workflow.phase.started(:workflow_id, :next_phase)

subscribe: distribot.workflow.phase.started(:workflow_id, :phase)
  * on receive:
    1. for each of this phase's handlers:
      a. publish: distribot.workflow.handler.$handler.enumerate(:workflow_id, :phase, :task_queue, :finished_queue, :cancel_consumer_queue)
      b. broadcast: distribot.workflow.handler.$handler.process(:workflow_id, :phase, :task_queue, :finished_queue, :cancel_consumer_queue)

subscribe: distribot.workflow.handler.enumerated(:workflow_id, :phase, :task_queue, :finished_queue, :handler)
  * on receive:
    1. subscribe to :finished_queue(:workflow_id, :phase, :handler)
      * on receive: remaining_jobs = decrement redis(:task_queue)
        1. if remaining_jobs <= 0:
          * publish: distribot.workflow.handler.finished(:workflow_id, :phase, :handler, :task_queue)
          * unsubscribe from :finished_queue

subscribe: distribot.workflow.handler.finished(:workflow_id, :phase, :handler, :task_queue)
  * on receive:
    1. if all handlers for :phase have completed
      * publish: distribot.workflow.phase.finished(:workflow_id, :phase)
      * broadcast: distribot.cancel.consumer(:task_queue)

subscribe: distribot.workflow.phase.finished(:workflow_id, :phase)
  * on receive:
    1. is there a :next_phase?
      * yes:
        1. workflow.transition_to( :next_phase )
        1. publish: distribot.workflow.phase.started(:workflow_id, :next_phase)
      * no:
        1. publish: distribot.workflow.finished(:workflow_id)

subscribe: distribot.workflow.finished(:workflow_id)
  * on receive:
    1. queue exists?(distribot.workflow.:workflow_id.finished):
      * yes:
        1. publish: distribot.workflow.:workflow_id.finished(:workflow_id)
    2. for each handler of each phase
      * broadcast: distribot.cancel.consumer(:task_queue)

## Worker Nodes

subscribe: distribot.workflow.handler.$handler.enumerate(:workflow_id, :phase, :task_queue, :finished_queue, :cancel_consumer_queue)
  * on receive:
    1. begin enumerating tasks
      * for each :task
        1. increment redis(:task_queue)
        2. publish: :task_queue(:task)
    2. publish: distribot.workflow.handler.enumerated(:workflow_id, :phase, :task_queue, :finished_queue, :handler)

subscribe: distribot.cancel.consumer(:task_queue)

subscribe_multi: distribot.workflow.handler.$handler.process(:workflow_id, :phase, :task_queue, :finished_queue, :cancel_consumer_queue)
  * on receive:
    1. subscribe: :task_queue(:task)
      * on receive:
        1. process :task
        2. publish: :finished_queue(:workflow_id, :phase, :handler)

