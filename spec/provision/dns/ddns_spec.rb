require 'provision/dns'
require 'provision/dns/ddns'
require 'tmpdir'
require 'provision/core/machine_spec'

class Provision::DNS::DDNS::Network
  attr_reader :network, :broadcast, :min_allocation, :max_allocation
end

class MockProvision < Provision::DNS::DDNS::Network
  attr_reader :update_files
  def initialize(options={})
    super
    @nsupdate_replies = options[:nsupdate_replies] || raise("Need :nsupdate_replies")
    @lookup_table = options[:lookup_table] || raise("Need :lookup_table")
    @update_files = []
  end

  def exec_nsupdate(update_file)
    @nsupdate_replies.shift
    @update_files.push(update_file)
  end

  def lookup_ip_for(hn)
    @lookup_table[hn] || false
  end
end

describe Provision::DNS::DDNS do
  it 'constructs once' do
    dns = Provision::DNS::DDNS::Network.new(
      :network_range => '192.168.1.0/24',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw=="
    )
    expect(dns.network.to_s).to eq('192.168.1.0')
    expect(dns.broadcast.to_s).to eq('192.168.1.255')
    expect(dns.min_allocation.to_s).to eq('192.168.1.10')
    expect(dns.max_allocation.to_s).to eq('192.168.1.254')
  end

  it 'is mocked in subclass as expected' do
    dns = MockProvision.new(
      :network_range => '192.168.1.0/24',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => [],
      :lookup_table => {
        'foo.example.com' => '172.16.0.1',
      }
    )
    expect( dns.lookup_ip_for('foo.example.com') ).to eq('172.16.0.1')
    expect( dns.lookup_ip_for('foo2example.com') ).to eq(false)
  end
end


