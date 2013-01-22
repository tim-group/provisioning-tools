require 'rubygems'
require 'spec_helper'
require 'pp'

describe 'provisionvm',:mcollective=>true do

  before do
    agent_file = File.join([File.dirname(__FILE__)], '../../../mcollective/agent/computenode.rb')
    @agent = MCollective::Test::LocalAgentTest.new("computenode", :agent_file=> agent_file).plugin
  end

  RSpec::Matchers.define :return_success do
    match do |response|
      response[:statuscode] == 0
    end

    failure_message_for_should do |response|
      response.pretty_inspect
    end

    description do |response|
      "the agent returned an error"
    end
  end

  it 'sends the specs to the provisioning-tools to be provisioned' do
    # TODO: Replace me with something more sensible
    #    m1 = {
    #      :hostname=>"machine1"
    #    }
    #    m2 = {
    #      :hostname=>"machine2"
    #    }
    #
    #    @agent.expects(:provision).with([m1,m2]).returns({"machine1"=>"success", "machine2"=>"success"})
    #    reply = @agent.call(:launch, :specs=>[m1,m2])
    #    pp reply
    #    reply[:data].should eq({"machine1"=>"success", "machine2"=>"success"})
  end

  it 'throws an appropriate error when there is nil passed' do
    @agent.config.pluginconf["provision.lockfile"] = "/tmp/provision.lock"
    response = @agent.call(:clean)
    response.should return_success
  end

end

