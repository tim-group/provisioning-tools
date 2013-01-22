require 'provision/dns'
require 'provision/dns/ddns'
require 'tmpdir'
require 'provision/core/machine_spec'

class Provision::DNS::DDNSNetwork
  attr_reader :network, :broadcast, :min_allocation, :max_allocation
end

class MockProvision < Provision::DNS::DDNSNetwork
  attr_reader :update_files
  def initialize(net,start, options={})
    super(net,start,options)
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
    dns = Provision::DNS::DDNSNetwork.new('192.168.1.0/24',nil,
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw=="
    )
    dns.network.to_s.should eql('192.168.1.0')
    dns.broadcast.to_s.should eql('192.168.1.255')
    dns.min_allocation.to_s.should eql('192.168.1.10')
    dns.max_allocation.to_s.should eql('192.168.1.254')
  end

  it 'is mocked in subclass as expected' do
    dns = MockProvision.new('192.168.1.0/24',nil,
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => [],
      :lookup_table => {
        'foo.example.com' => '172.16.0.1',
      }
    )
    dns.reverse_zone.should eql('1.168.192.in-addr.arpa')
    dns.lookup_ip_for('foo.example.com').should eql('172.16.0.1')
    dns.lookup_ip_for('foo2example.com').should eql(false)
  end

  it 'calculates /16 reverse zones right' do
    dns = MockProvision.new('192.168.1.0/16',nil,
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => [],
      :lookup_table => {
      }
    )
    dns.reverse_zone.should eql('168.192.in-addr.arpa')
  end
end


