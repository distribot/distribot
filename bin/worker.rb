#!/usr/bin/env ruby


require 'bundler/setup'
require 'distribot'
require 'byebug'
require 'pp'
require 'active_support/core_ext/object'
require 'active_support/core_ext/array'
require 'active_support/json'

class BaseWorker
  def self.perform(context, job, &callback)
    puts "#{self}: Doing job '#{job}'... #{context.workflow_id}.#{context.phase}"
# `curl -k http://www.example.com/robots.txt?#{self} > /dev/null`
    callback.call()
  end

  def self.enumerate_jobs(context, workflow, &callback)
    # get whatever we need from workflow.meta
    jobs = (1..10).to_a
puts "----------- ABOUT TO ENUMERATE JOBS for #{context.workflow_id}.#{context.phase} --------------"
    jobs.in_groups_of(20, false).each do |chunk|
      callback.call(chunk.map{|num| {a_number: num} })
    end
  end
end

class SimpleWorker < BaseWorker; end

module Example
  def self.make_workflow(name)
    name += "#1"
    @workflow = Distribot::Workflow.new(
      name: name,
      phases: [
        {
          name: 'pending',
          is_initial: true,
          transitions_to: 'phase-a-licious'
        },
        {
          name: 'phase-a-licious',
          handlers: [ 'SimpleWorker' ],
          transitions_to: 'finished'
        },
        {
          name: 'finished',
          is_final: true
        }
      ]
    )
    @workflow.save!
  end
end

Distribot.configure do |config|
  config.redis_url = 'redis://172.17.0.2:6379/0'
  config.rabbitmq_url = 'amqp://distribot:distribot@172.17.0.2:5672'
end

handler_runner = Distribot::HandlerRunner.new
phase_enqueued = Distribot::PhaseEnqueuedHandler.new
puts "Started handler runner..."
sleep

