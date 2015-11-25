require 'spec_helper'

describe Distribot::Workflow do
  before do
    @json = JSON.parse( File.read('spec/fixtures/simple_workflow.json'), symbolize_names: true )
  end
  it 'can be initialized' do
    workflow = Distribot::Workflow.new(name: @json[:workflow], phases: @json[:phases] )
    expect(workflow.name).to eq @json[:workflow]
    expect(workflow.phases.count).to eq @json[:phases].keys.count
  end
end

