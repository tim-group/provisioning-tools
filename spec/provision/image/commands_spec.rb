require 'provisioning-tools/provision/image/namespace'
require 'provisioning-tools/provision/image/commands'
require 'provisioning-tools/provision/log'

describe Provision::Image::Commands do
  it 'times out when condition never comes true' do
    @logdir = "build"
    @thread_number = 1
    extend Provision::Log
    extend Provision::Image::Commands
    i = 0
  end

  it 'continues when condition comes true' do
    @logdir = "build"
    @thread_number = 1
    extend Provision::Log
    extend Provision::Image::Commands
    i = 0
    keep_doing do
      i += 1
      print i
    end.until { i == 5 }

    i.should eql(5)
  end
end
