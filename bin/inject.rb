#!/usr/bin/env ruby

require 'bundler/setup'
require 'distribot'
require 'byebug'
require 'pp'
require 'active_support/core_ext/object'
require 'active_support/core_ext/array'
require 'active_support/json'



def make_workflow(name)
  workflow = Distribot::Workflow.new(
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
        transitions_to: 'phase-a-RAMA'
      },
      {
        name: 'phase-a-RAMA',
        handlers: [ 'SimpleWorker' ],
        transitions_to: 'finished'
      },
      {
        name: 'finished',
        is_final: true
      }
    ],
  )
  workflow.save! do |result|
    puts "YAY for finishing workflows: (#{result})"
  end
  return workflow
end

make_workflow(ARGV.shift)
