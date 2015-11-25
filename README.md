
# Distributed workflow engine

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
  config.rabbitmq_url = 'amqp://username:password@your.hostname.com:5762'
  config.redis_url = 'redis://your.redis.hostname:6379/0'
end
```

## The Big Idea

**Workflow:**
  * inserts a message into the 'is_initial' phase's queue.
  * waits for a message on the PhaseFinished queue.
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
    * if they are, then it inserts a message into the PhaseFinished queue.
      : {status: success, phase: my-phase-name, started_at: X'oclock, finished_at: Y'oclock}

**Handlers:**
  * have their own queues
  * can run together or separately on one or more instances
  * after each message, announces in a finished queue that it has completed a job

```json
{
  "workflow": "search",
  "phases": {
    "pending": {
      "is_initial": true,
      "transitions_to": "searching",
      "on_error_transition_to": "error"
    },
    "searching": {
      "transitions_to": "fetching-pages",
      "on_error_transition_to": "error",
      "handlers": [
        "GoogleSearcher"
      ]
    },
    "fetching-pages": {
      "transitions_to": "finished",
      "on_error_transition_to": "error",
      "handlers": [
        "PageDownloader"
      ]
    },
    "error": {
      "is_final": true,
      "handlers": [
        "ErrorEmailer"
      ]
    },
    "finished": {
      "is_final": true,
      "handlers": [
        "JobFinisher"
      ]
    }
  }
}
```
