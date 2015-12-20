
# Distribot

[![Code Climate](https://codeclimate.com/github/jdrago999/distribot/badges/gpa.svg)](https://codeclimate.com/github/jdrago999/distribot)
[![Test Coverage](https://codeclimate.com/github/jdrago999/distribot/badges/coverage.svg)](https://codeclimate.com/github/jdrago999/distribot/coverage)

Work scheduling and distribution engine.

## Features

  * Built on RabbitMQ and Redis.

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
  config.redis_url = ENV['DISTRIBOT_REDIS_URL']
  config.rabbitmq_url = ENV['DISTRIBOT_RABBITMQ_URL']
end
```

```json
{
  "name": "search",
  "phases": [
    {
      "name": "pending",
      "is_initial": true,
      "transitions_to": "searching"
    },
    {
      "name": "searching",
      "transitions_to": "fetching-pages",
      "handlers": [
        "GoogleSearcher",
        "BingSearcher"
      ]
    },
    {
      "name": "fetching-pages",
      "transitions_to": "finished",
      "handlers": [
        {
          "name": "PageDownloader",
          "version": "~> 1.2"
        }
      ]
    },
    {
      "name": "finished",
      "is_final": true
    }
  ]
}
```

# TODO

### Features

  * ~~Ability to control running workflows~~
    * ~~cancel~~
    * ~~pause~~
    * ~~resume~~
  * ~~Handler versioning~~
    * ~~semver~~
    * ~~specify handler versions in workflow definitions~~
      * ~~similar to gemfile~~

### Organization

  * Break this project into smaller parts.
    * gem code
      * ~~should not require infrastructure to run tests~~
      * ~~enough infrastructure to run the code~~
    * small running environment which uses the gem
      * engine
      * worker
      * controller
      * ~~infra~~
        * ~~redis~~
        * ~~rabbitmq~~
        * ~~elasticsearch~~
        * ~~kibana~~
  * status dashboard
    * show running workflows


## Notes

Clear out queues:

`sudo rabbitmqctl list_queues | grep distribot | awk '{print $1}' | xargs -I qn rabbitmqadmin delete queue name=qn`

