require 'provision/dns'
require 'provision/dns/ddns'
require 'tmpdir'
require 'provision/core/machine_spec'

class Provision::DNS::DDNSNetwork
  attr_reader :network, :broadcast, :min_allocation, :max_allocation
end

class MockProvision < Provision::DNS::DDNSNetwork
  attr_reader :update_files
  def initialize(name, net, options={})
    super(name, net, options)
    @nsupdate_replies = options[:nsupdate_replies] || raise("Need :nsupdate_replies")
    @lookup_table = options[:lookup_table] || raise("Need :lookup_table")
    @update_files = []
  end

  def exec_nsupdate(update_file)
    @update_files.push(IO.read(update_file.path))
    @nsupdate_replies.shift
  end

  def lookup_ip_for(hn)
    @lookup_table[hn] || false
  end
end

describe Provision::DNS::DDNS do
  def get_spec
    spec = double()
    spec.stub(:hostname_on).and_return('st-testmachine-001.mgmt.st.net.local')
    spec
  end

  it 'constructs once' do
    dns = Provision::DNS::DDNSNetwork.new('prod', '192.168.1.0/24',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :primary_nameserver => "mars"
    )
    dns.network.to_s.should eql('192.168.1.0')
    dns.broadcast.to_s.should eql('192.168.1.255')
    dns.min_allocation.to_s.should eql('192.168.1.10')
    dns.max_allocation.to_s.should eql('192.168.1.254')
  end

  it 'will restrict ip allocations to min and max allocations' do
    dns = Provision::DNS::DDNSNetwork.new('prod', '192.168.1.0/24',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :primary_nameserver => "mars",
      :min_allocation => "192.168.1.99",
      :max_allocation => "192.168.1.150"
    )
    dns.network.to_s.should eql('192.168.1.0')
    dns.broadcast.to_s.should eql('192.168.1.255')
    dns.min_allocation.to_s.should eql('192.168.1.99')
    dns.max_allocation.to_s.should eql('192.168.1.150')
  end

  it 'is mocked in subclass as expected' do
    dns = MockProvision.new('prod', '192.168.1.0/24',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => [],
      :lookup_table => {
        'foo.example.com' => '172.16.0.1',
      },
      :primary_nameserver => "mars"
    )
    dns.reverse_zone.should eql('1.168.192.in-addr.arpa')
    dns.lookup_ip_for('foo.example.com').should eql('172.16.0.1')
    dns.lookup_ip_for('foo2example.com').should eql(false)
  end

  it 'calculates /16 reverse zones right' do
    dns = MockProvision.new('prod', '192.168.1.0/16',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => [],
      :lookup_table => {
      },
      :primary_nameserver => "mars"
    )
    dns.reverse_zone.should eql('168.192.in-addr.arpa')
  end

  it 'raises an exception if we get bad rndc key' do
    dns = MockProvision.new('prod', '192.168.1.0/16',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => ['; TSIG error with server: tsig indicates error (RuntimeError)
update failed: NOTAUTH(BADKEY)
'],
      :lookup_table => {},
      :primary_nameserver => "mars"
    )
    expect { dns.allocate_ip_for(get_spec()) }.to raise_error(Provision::DNS::DDNS::Exception::BadKey)
  end

  it 'raises an exception if we get a timeout' do
    dns = MockProvision.new('prod', '192.168.1.0/16',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => ['; Communication with server failed: timed out'],
      :lookup_table => {},
      :primary_nameserver => "mars"
    )
    expect { dns.allocate_ip_for(get_spec()) }.to raise_error(Provision::DNS::DDNS::Exception::Timeout)
  end

  it 'can allocate a name' do
    dns = MockProvision.new('prod', '192.168.1.0/16',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => ['', ''],
      :lookup_table => {},
      :primary_nameserver => "mars"
    )
    ip = dns.allocate_ip_for(get_spec())
    ip[:address].to_s.should eql('192.168.0.10')
    ip[:netmask].should eql('255.255.0.0')
  end

  it 'can de-allocate an already allocated name' do
    dns = MockProvision.new('prod', '192.168.1.0/16',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => ['', '', '', ''],
      :lookup_table => {'st-testmachine-001.mgmt.st.net.local' => '192.168.0.10'},
      :primary_nameserver => "mars"
    )
    ip = dns.allocate_ip_for(get_spec())
    dns.remove_ip_for(get_spec())
    dns.update_files.size.should eql(2)
    dns.update_files[0].should =~ /update delete st-testmachine-001\.mgmt\.st\.net\.local\. A\n/
    dns.update_files[1].should =~ /update delete 10\.0\.168\.192\.in-addr\.arpa\. PTR\n/
  end

  it 'can de-allocate a not already allocated name' do
    dns = MockProvision.new('prod', '192.168.1.0/16',
      :rndc_key      => "fa5dUl+sdm/8cSZtDv1xFw==",
      :nsupdate_replies => [],
      :lookup_table => {},
      :primary_nameserver => "mars"
    )
    dns.remove_ip_for(get_spec())
    dns.update_files.size.should eql(0)
  end

end


