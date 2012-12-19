require 'rubygems'
require 'spec_helper'

describe 'provisionvm' do

  before do
    agent_file = File.join([File.dirname(__FILE__)], '../../../lib/mcollective/agent/Provisionvm.rb')
    @agent = MCollective::Test::LocalAgentTest.new("provisionvm", :agent_file=> agent_file).plugin
  end

  it 'responds with available if the host can use this vm' do
    m1 = {
      :hostname=>"machine1"
    }
    m2 = {
      :hostname=>"machine2"
    }
    reply = @agent.call(:find_hosts, :specs=>[m1,m2])
    reply[:data].should eq({"machine1"=>"OK", "machine2"=>"OK"})
  end


  it 'sends the specs to the provisioning-tools to be provisioned' do
    m1 = {
      :hostname=>"machine1"
    }
    m2 = {
      :hostname=>"machine2"
    }

    @agent.expects(:provision).with([m1,m2]).returns({"machine1"=>"success", "machine2"=>"success"})
    reply = @agent.call(:provision_vms, :specs=>[m1,m2])
    pp reply
    reply[:data].should eq({"machine1"=>"success", "machine2"=>"success"})
  end

end
