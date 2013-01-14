require 'provision/dns'
require 'provision/dns/ddns'
require 'tmpdir'
require 'provision/core/machine_spec'

class Provision::DNS::DDNS
  attr_reader :network, :broadcast, :min_allocation, :max_allocation
end

describe Provision::DNS::DDNS do
  it 'constructs once' do
    dns = Provision::DNS::DDNS.new(:network_range => '192.168.1.0/24')
    expect(dns.network.to_s).to eq('192.168.1.0')
    expect(dns.broadcast.to_s).to eq('192.168.1.255')
    expect(dns.min_allocation.to_s).to eq('192.168.1.10')
    expect(dns.max_allocation.to_s).to eq('192.168.1.254')
  end
end

