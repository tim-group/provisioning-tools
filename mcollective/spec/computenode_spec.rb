require 'rubygems'
require 'spec_helper'
require 'pp'
require 'provision'

describe 'provisionvm', :mcollective => true do

  before do
    agent_file = File.join([File.dirname(__FILE__)], '../../mcollective/agent/computenode.rb')
    @agent = MCollective::Test::LocalAgentTest.new("computenode", :agent_file =>  agent_file).plugin
    @agent.config.pluginconf["provision.lockfile"] = "/tmp/provision.lock"
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

  class Provision::Config
    def get()
      nil
    end
  end

  it 'sends the specs to the provisioning-tools to be provisioned' do
    m1 = {
      :hostname => "machine1"
    }
    m2 = {
      :hostname => "machine2"
    }

    @agent.expects(:provision).with([m1, m2], anything).returns({"machine1" => "success", "machine2" => "success"})
    reply = @agent.call(:launch, :specs => [m1, m2])
    reply[:data].should eq({"machine1" => "success", "machine2" => "success"})
  end

end
