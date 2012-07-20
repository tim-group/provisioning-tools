require 'provision/image/namespace'
require 'provision/image/commands'

describe Provision::Image::Commands do
  it 'times out when condition never comes true' do
    extend Provision::Image::Commands
    i=0;
    expect {wait_until {i==5}}.should raise_error(Exception)
  end

  it 'continues when condition comes true' do
    extend Provision::Image::Commands
    i=0;
    wait_until {i+=1; i==5}    
  end
end
