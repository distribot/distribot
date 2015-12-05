require 'spec_helper'

describe Distribot::Worker do
  describe '.included(klass)' do
    before do
      @klass = "Foo#{SecureRandom.hex(10)}"
      eval <<-EOF
class #{@klass}
  include Distribot::Worker
end
      EOF
    end
    it 'adds an enumerate_with(:callback) method' do
      expect(Kernel.const_get(@klass)).to respond_to(:enumerate_with)
    end
    it 'adds an enumerator accessor' do
      Kernel.const_get(@klass).send :enumerate_with, 'foo'
      expect(Kernel.const_get(@klass).send :enumerator).to eq 'foo'
    end
    it 'adds a process_tasks_with(:callback) method' do
      expect(Kernel.const_get(@klass)).to respond_to(:process_tasks_with)
    end
    it 'adds a processor accessor' do
      Kernel.const_get(@klass).send :process_tasks_with, 'foo'
      expect(Kernel.const_get(@klass).send :processor).to eq 'foo'
    end
    it 'adds an enumeration_queue accessor' do
      expect(Kernel.const_get(@klass).send :enumeration_queue).to eq "distribot.workflow.handler.#{@klass}.enumerate"
    end
    it 'adds a process_queue accessor' do
      expect(Kernel.const_get(@klass).send :process_queue).to eq "distribot.workflow.handler.#{@klass}.process"
    end
  end

  describe '#initialize' do
    before :all do
      @klass = "FooWorker#{SecureRandom.hex(8)}"
      eval <<-EOF
class #{@klass}
  include Distribot::Worker
  enumerate_with :enumerate
  process_tasks_with :process

  def enumerate(context, &callback)
    jobs = ['job1', 'job2']
    callback.call( jobs )
  end

  def process(job)
    job
  end
end
      EOF
    end
    it '???' do
      Kernel.const_get(@klass).new.enumerate({foo: :bar}) do |tasks|
        expect(tasks).to eq ['job1', 'job2']
      end
    end
  end
end
