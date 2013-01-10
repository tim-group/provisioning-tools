require 'provision/dns'
require 'provision/dns/ddns'
require 'tmpdir'
require 'provision/core/machine_spec'

describe Provision::DNS::DDNS do
  it 'constructs once' do
    Provision::DNS::DDNS.new
  end
end

