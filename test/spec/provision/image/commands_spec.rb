require 'provision/image/namespace'
require 'provision/image/commands'

describe Provision::Image::Commands do
  it 'times out when condition never comes true' do
    @logdir = "build"
    @thread_number = 1
    extend Provision::Log
    extend Provision::Image::Commands
    i=0;
    expect {wait_until("blah", :retry_commands=>1) {i==5}}.should raise_error(Exception)
  end

  it 'continues when condition comes true' do
    @logdir = "build"
    @thread_number = 1
    extend Provision::Log
    extend Provision::Image::Commands
    i=0;
    wait_until {i+=1; i==5}    
  end
end
