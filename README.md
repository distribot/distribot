
# Distribot

A distributed workflow engine for rabbitmq.

![robot](https://cdn2.iconfinder.com/data/icons/windows-8-metro-style/512/robot.png)

## Installation

### In your Gemfile

```ruby
gem 'distribot', git: 'git@github.com:jdrago999/distribot.git'
```

## Usage

```ruby
require 'distribot'

Distribot.configure do |config|
  # Consider using environment variables instead of hard-coding these values.
  # For ideas, look at the excellent 'dotenv' gem.
  config.redis_url = ENV['DISTRIBOT_REDIS_URL']
  config.rabbitmq_url = ENV['DISTRIBOT_RABBITMQ_URL']
end
```

## The Big Idea

**Workflow:**
  * inserts a message into the 'is_initial' phase's queue.
  * waits for a message on the [PhaseName]Finished queue.
    * when a message is received, transitions the workflow to the next phase.
      * stores the new phase in its db record as 'current phase'
      * adds a transition record to the workflow's transitions table
      * inserts a message into the next phase's queue. (or finishes the workflow if the current phase is_final).

**Phases:**
  * have their own queues
  * can run on one or more instances
  * on enter phase:
    * inserts jobs into each of its handlers' queues
    * then starts listening to the phase's job-finished queue.

**[PhaseName]JobFinished Handler:**
  * checks to see if all of its handlers' queues are empty.
    * if they are, then it inserts a message into the [PhaseName]Finished queue.
      : {status: success, phase: my-phase-name, started_at: X'oclock, finished_at: Y'oclock}

**Handlers:**
  * have their own queues
  * can run together or separately on one or more instances
  * after each message, announces in a finished queue that it has completed a job

```json
{
  "name": "search",
  "phases": [
    {
      "name": "pending",
      "is_initial": true,
      "transitions_to": "searching",
      "on_error_transition_to": "error"
    },
    {
      "name": "searching",
      "transitions_to": "fetching-pages",
      "on_error_transition_to": "error",
      "handlers": [
        "GoogleSearcher"
      ]
    },
    {
      "name": "fetching-pages",
      "transitions_to": "finished",
      "on_error_transition_to": "error",
      "handlers": [
        "PageDownloader"
      ]
    },
    {
      "name": "error",
      "is_final": true,
      "handlers": [
        "ErrorEmailer"
      ]
    },
    {
      "name": "finished",
      "is_final": true,
      "handlers": [
        "JobFinisher"
      ]
    }
  ]
}
```


## Queues:

  * distribot.workflow.created (global)
    * transition to next phase

  * distribot.workflow.phase.started
    * enqueue jobs for handlers in their respective queues
      * we set a counter value in redis to indicate the number of total tasks for each handler.
    * announce in distribot.workflow.tasks.enqueued that we should be waiting for them to finish by listening to queues X and Y

  * distribot.workflow.phase.enqueued
    * messages contain:
      * the names of the queues ($QUEUE_X, $QUEUE_Y) that the tasks were inserted into
      * how many tasks should be completed
      * starts listening to distribot.workflow.task.finished

  * distribot.workflow.$WORKFLOW_ID.$PHASE_NAME.$HANDLER_NAME.tasks
    * contains JSON messages which describe individual tasks for a given handler.
    * workers subscribe, perform the task, and mark each task as complete by sending a message to distribot.workflow.$WORKFLOW_ID.$PHASE_NAME.$HANDLER_NAME.task.finished

  * distribot.workflow.$WORKFLOW_ID.$PHASE_NAME.$HANDLER_NAME.task.finished
    * told that another task has finished for a phase? a handler?
    * decrements the counter value in redis
    * when the counter value reaches zero then announce in distribot.workflow.phase.finished

  * distribot.workflow.phase.finished
    * if we can move forward, then transition to next phase
    * if we cannot, then msg distribot.workflow.finished

  * distribot.workflow.finished (global)
    * ping the calling system to let it know that the workflow has finished.


## Classes:

  * `WorkflowCreatedHandler`(reads: `distribot.workflow.created`)
  * `PhaseStartedHandler`(reads: `distribot.workflow.phase.started`, writes: `distribot.workflow.phase.enqueued`)
    * tells the `$HANDLER` to enumerate the jobs, then enqueues them itself.
    * announces on `distribot.workflow.handler.start` that a `$HANDLER` must start and listen to the `$QUEUE`.
    * has a callback to announce job queue names.
```ruby
phase.handlers.map do |handler|
  queue = queue_name_from(workflow, phase, handler)
  count = enqueuer.enqueue(queue, handler)
  announce_to(distribot.workflow.phase.enqueued, { job_count: count, handler: handler, queue: queue }.to_json)
end
```
  * `HandlerRunner`(reads: `distribot.workflow.handler.start`)
    * listens for a message about which `$HANDLER` to start and which `$QUEUE` it should be fed from.
    * starts a handler
    * feeds it messages until the task count has reached zero.
    * kills the handler
  * `PhaseEnqueuedHandler`(reads: `distribot.workflow.phase.enqueued`)
    * starts a TaskFinishedHandler instance for each of the queues.
    * waits for each of them to exit their blocking loop after all their tasks have completed.
    * `TaskFinishedHandler`(reads: `distribot.workflow.$WORKFLOW_ID.$PHASE_NAME.$HANDLER_NAME.task.finished`)
      * decrements its counter in redis
      * if the counter is now zero, then exits (maybe raises a `HandlerTasksAllFinishedSir` exception)
    * when all the `TaskFinishedHandler` instances have finished:
      * announce to `distribot.workflow.phase.finished`
  * `PhaseFinishedHandler`(reads: `distribot.workflow.phase.finished`)
    * if we can move forward, then transition to next phase
    * if we cannot, then msg `distribot.workflow.finished`
  * `WorkflowFinishedHandler`(reads: `distribot.workflow.finished`)
    * ping the calling system to let it know that the workflow has finished.




```bash
# Empty leftover queues:
sudo rabbitmqctl list_queues | grep distribot | awk '{print $1}' | xargs -I qn rabbitmqadmin delete queue name=qn
```



