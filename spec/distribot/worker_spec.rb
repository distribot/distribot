require 'spec_helper'

describe Distribot::Worker do
  before do
    Distribot.stub(:subscribe)
  end
  describe 'definition' do
  end

  describe '#callback' do
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
