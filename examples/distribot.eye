#!/usr/bin/env ruby
#^syntax detection

# The excellent dotenv gem.
# See https://github.com/bkeepers/dotenv for details.
require 'dotenv'
Dotenv.load

ROOT = File.expand_path('../../', __FILE__)

Eye.config do
  logger "#{ROOT}/log/eye.log"
end

unless File.directory? "#{ROOT}/log"
  `mkdir -p #{ROOT}/log`
end
unless File.directory? "#{ROOT}/tmp"
  `mkdir -p #{ROOT}/tmp`
end

Eye.application :distribot do
  working_dir ROOT
  trigger :flapping, :times => 10, :within => 1.minute

  # Usage:
  # eye load eye/distribot.eye
  # eye start all
  # eye stop all
  # eye restart distribot:phase-started
  # tail -f log/*
  # See https://github.com/kostya/eye for details.

  things = %w(
    phase-started
    phase-finished
    task-finished
    handler-finished
    workflow-finished
    workflow-created
  )

  things.each do |thing|
    process thing do
      daemonize true
      pid_file "tmp/#{thing}.pid"
      stdall "log/#{thing}.log"
      start_command "dotenv distribot.#{thing}"
      stop_signals [:TERM, 5.seconds, :KILL]
      restart_command "kill -USR2 {PID}"
      restart_grace 10.seconds
    end
  end
end
