

* **subscribe:** `distribot.workflow.created`($workflow)
  * **publish:** `distribot.workflow.phase.started`($workflow, $workflow.first_phase)`

----

* **subscribe:** `distribot.workflow.phase.started`($workflow, $phase)
  * No handlers:
```ruby
      phase.handlers.each do |handler|
        $task_queue = `distribot.workflow.$id.$phase.$handler.tasks`
        $finished_queue = `distribot.workflow.$id.$phase.$handler.finished`
        **publish:** `distribot.workflow.handler.$handler.enumerate`($task_queue)
        **broadcast:** `distribot.workflow.handler.$handler.process`($task_queue, $finished_queue)
        **publish:** `distribot.workflow.await-finished-tasks`($finished_queue)
      end
```
  * With handlers:
    * **publish:** `distribot.workflow.phase.finished`

----

* **subscribe:** `distribot.workflow.handler.started`($handler)
  * call out to enumerate the jobs:
    * **publish:** `distribot.workflow.handler.enumerate`
      * $workflow, $phase, $handler
  * call out to start working on the jobs:
    * **broadcast:** `distribot.workflow.handler.start`($workflow, $phase, $handler, $task_queue)

----

* **subscribe:** `distribot.workflow.await-finished-tasks`($finished_queue)
  * **subscribe:** $finished_queue
    * decrement counter in redis.
    * if counter <= 0
      * **publish:** `distribot.workflow.handler.finished`($workflow, $phase, $handler)

----

* **subscribe:** `distribot.workflow.phase.started`($finished_queue)
  * @consumer = **subscribe:** $finished_queue
    * mark $task as complete in the $finished_counter
  * **subscribe_multi:** `distribot.workflow.phase.finished`($finished_queue)
    * delete matching @consumer for $finished_queue

----

* **subscribe:** `distribot.workflow.handler.$handler.enumerate`($task_queue)
  * $handler.enumerate.map{|x| $task_queue.insert(x) }
  * **broadcast:** `distribot.workflow.handler.enumerated`($workflow, $phase, $handler)

----

* **subscribe_multi:** `distribot.workflow.handler.$handler.process`($task_queue)
  * pull from $task_queue
  * publish to $finished_queue

----

* **subscribe:** `distribot.workflow.handler.finished`($workflow, $phase, $handler)
  * if all the handlers in this phase have finished:
    * **publish:** `distribot.workflow.phase.finished`($workflow, $phase)

----

* **subscribe:** `distribot.workflow.phase.finished`($workflow, $phase)
```ruby
  if $workflow.phase == $phase
    if $workflow.next_phase?
      $workflow.transition_to($workflow.next_phase)
    else
      **publish:** `distribot.workflow.finished`
    end
  else
    # Do nothing, because the world state has changed before we got to process this message.
  end
```
