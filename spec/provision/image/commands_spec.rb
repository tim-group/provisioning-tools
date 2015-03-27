require 'spec_helper'
require 'provision/image/namespace'
require 'provision/image/commands'
require 'provision/log'

describe Provision::Image::Commands do
  it 'times out when condition never comes true' do
    @logdir = "build"
    @thread_number = 1
    extend Provision::Log
    extend Provision::Image::Commands
    i = 0;
#    expect {
#	keep_doing {}.until {i==5}
#    }.should raise_error(Exception)
  end

  it 'continues when condition comes true' do
    @logdir = "build"
    @thread_number = 1
    extend Provision::Log
    extend Provision::Image::Commands
    i = 0;
    keep_doing do
      i += 1
      print i
    end.until { i == 5 }

    i.should eql(5)
  end
end
