require 'spec_helper'
require 'provisioning-tools/provision/dns'
require 'provisioning-tools/provision/dns/dnsmasq'
require 'tmpdir'
require 'provisioning-tools/provision/core/machine_spec'

class Provision::DNS::DNSMasqNetwork
  attr_reader :network, :broadcast, :min_allocation, :max_allocation
end

class Provision::DNS::DNSMasq
  attr_reader :networks

  def reload(network)
    @networks[network.to_sym].reload_dnsmasq
  end

  def hosts_by_name(network)
    @networks[network.to_sym].by_name
  end
end

describe Provision::DNS::DNSMasq do
  def mksubdirs(dir)
    Dir.mkdir("#{dir}/etc")
    Dir.mkdir("#{dir}/var")
    Dir.mkdir("#{dir}/var/run")
  end

  before :each do
    @checker = double
  end

  def undertest(dir, options = {})
    dnsmasq = Provision::DNS.get_backend("DNSMasq", options)
    dnsmasq.add_network(:mgmt, "192.168.5.0/24", :min_allocation => "192.168.5.2", :max_allocation => "192.168.5.250",
                                                 :hosts_file => "#{dir}/etc/hosts",
                                                 :pid_file => "#{dir}/var/run/dnsmasq.pid", :checker => @checker)
    dnsmasq.add_network(:prod, "192.168.6.0/24", :min_allocation => "192.168.6.2", :hosts_file => "#{dir}/etc/hosts",
                                                 :pid_file => "#{dir}/var/run/dnsmasq.pid", :checker => @checker)
    dnsmasq
  end

  it 'will raise exception when allocating address for non existing network' do
    Dir.mktmpdir do |dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "# Example hosts file\n127.0.0.1 localhost\n" }

      mock_logger = double
      mock_logger.should_receive(:warn).with(/[:prod,:noexist]/)

      thing = undertest(dir, :logger => mock_logger)

      thing.remove_ips_for(Provision::Core::MachineSpec.new(
                             :hostname => "example",
                             :domain => "youdevise.com",
                             :qualified_hostnames => {
                               :prod => 'example.youdevise.com',
                               :noexist => 'example.mgmt.youdevise.com'
                             },
                             :networks => [:prod, :noexist]
      ))
    end
  end

  it 'will restrict ip allocations to min and max allocations' do
    Dir.mktmpdir do |dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "# Example hosts file\n127.0.0.1 localhost\n" }

      mock_logger = double

      thing = undertest(dir, :logger => mock_logger)
      thing.networks[:mgmt].network.to_s.should eql('192.168.5.0')
      thing.networks[:mgmt].broadcast.to_s.should eql('192.168.5.255')
      thing.networks[:mgmt].min_allocation.to_s.should eql('192.168.5.2')
      thing.networks[:mgmt].max_allocation.to_s.should eql('192.168.5.250')
      thing.networks[:prod].max_allocation.to_s.should eql('192.168.6.254')
    end
  end

  it 'throws an appropriate error when subnet is invalid' do
    expect do
      Provision::DNS::DNSMasqNetwork.new('foo', 'biscuits', {})
    end.to raise_exception(ArgumentError, 'invalid address')
  end

  def expect_checks(allocations)
    allocations.each do |hostname, ip|
      @checker.should_receive(:resolve_forward).with(hostname).and_return([ip])
      @checker.should_receive(:resolve_reverse).with(ip).and_return([hostname])
    end
  end

  def expect_cname_checks(allocations)
    allocations.each do |hostname, ip|
      @checker.should_receive(:resolve_forward).with(hostname).and_return(ip)
    end
  end

  it 'constructs once' do
    Dir.mktmpdir do |dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "# Example hosts file\n127.0.0.1 localhost\n" }
      thing = undertest(dir)
      expect_checks('example.mgmt.youdevise.com' => '192.168.5.2', 'example.youdevise.com' => '192.168.6.2')
      ip = thing.allocate_ips_for(Provision::Core::MachineSpec.new(
                                    :hostname => "example",
                                    :domain => "youdevise.com",
                                    :qualified_hostnames => {
                                      :prod => 'example.youdevise.com',
                                      :mgmt => 'example.mgmt.youdevise.com'
                                    }
      ))[:mgmt][:address]
      ip.kind_of?(IPAddr).should eql(false)
      ip.to_s.should eql("192.168.5.2")
      expect_checks('example2.mgmt.youdevise.com' => '192.168.5.3', 'example2.youdevise.com' => '192.168.6.3')
      other = thing.allocate_ips_for(Provision::Core::MachineSpec.new(
                                       :hostname => "example2",
                                       :domain => "youdevise.com",
                                       :qualified_hostnames => {
                                         :prod => 'example2.youdevise.com',
                                         :mgmt => 'example2.mgmt.youdevise.com'
                                       }
      ))[:mgmt][:address]
      other.to_s.should eql("192.168.5.3")
      first_again = thing.allocate_ips_for(Provision::Core::MachineSpec.new(
                                             :hostname => "example",
                                             :domain => "youdevise.com",
                                             :qualified_hostnames => {
                                               :prod => 'example.youdevise.com',
                                               :mgmt => 'example.mgmt.youdevise.com'
                                             }
      ))[:mgmt][:address]

      first_again.to_s.should eql("192.168.5.2")

      new_thing = undertest(dir)
      new_thing_ip = new_thing.allocate_ips_for(Provision::Core::MachineSpec.new(
                                                  :hostname => "example",
                                                  :domain => "youdevise.com",
                                                  :qualified_hostnames => {
                                                    :prod => 'example.youdevise.com',
                                                    :mgmt => 'example.mgmt.youdevise.com'
                                                  }
      ))[:mgmt][:address]
      new_thing_ip.to_s.should eql("192.168.5.2")

      new_thing.hosts_by_name(:mgmt).should eql("example.mgmt.youdevise.com" => "192.168.5.2",
                                                "example2.mgmt.youdevise.com" => "192.168.5.3")
    end
  end

  it 'parses wacky /etc/hosts' do
    Dir.mktmpdir do |dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') do |f|
        f.write \
          "192.168.5.5\t    fnar fnar.example.com\n" \
          "192.168.5.2   \t boo.example.com\tboo   \n" \
          "# Example hosts file\n" \
          "192.168.5.1 flib   \n"
      end
      thing = undertest(dir)
      thing.hosts_by_name(:mgmt).should eql("fnar" => "192.168.5.5",
                                            "fnar.example.com" => "192.168.5.5",
                                            "boo.example.com" => "192.168.5.2",
                                            "boo" => "192.168.5.2",
                                            "flib" => "192.168.5.1")
    end
  end

  it 'writes hosts out' do
    Dir.mktmpdir do |dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "\n" }
      thing = undertest(dir)

      spec = Provision::Core::MachineSpec.new(
        :hostname => "example",
        :domain => "youdevise.com",
        :aliases => %w(puppet broker),
        :qualified_hostnames => {
          :prod => 'example.youdevise.com',
          :mgmt => 'example.mgmt.youdevise.com'
        }
      )

      expect_checks('example.mgmt.youdevise.com' => '192.168.5.2', 'example.youdevise.com' => '192.168.6.2')

      thing.allocate_ips_for(spec)

      File.open("#{dir}/etc/hosts", 'r') do |f|
        f.read.should eql("\n192.168.5.2 example.mgmt.youdevise.com puppet.mgmt.youdevise.com " \
                          "broker.mgmt.youdevise.com\n192.168.6.2 example.youdevise.com\n")
      end
    end
  end

  it 'removes entries from hosts file' do
    Dir.mktmpdir do |dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "" }
      thing = undertest(dir)
      spec1 = Provision::Core::MachineSpec.new(
        :hostname => "example",
        :domain => "youdevise.com",
        :aliases => %w(puppet broker),
        :qualified_hostnames => {
          :prod => 'example.youdevise.com',
          :mgmt => 'example.mgmt.youdevise.com'
        }
      )
      spec2 = Provision::Core::MachineSpec.new(
        :hostname => "example2",
        :domain => "youdevise.com",
        :aliases => %w(puppet broker),
        :qualified_hostnames => {
          :prod => 'example2.youdevise.com',
          :mgmt => 'example2.mgmt.youdevise.com'
        }
      )

      spec1.hostname_on(:mgmt).should eql('example.mgmt.youdevise.com')
      spec1.hostname_on(:prod).should eql('example.youdevise.com')
      expect_checks('example.mgmt.youdevise.com' => '192.168.5.2', 'example.youdevise.com' => '192.168.6.2')
      ip_spec = thing.allocate_ips_for(spec1)
      ip_spec.should eql(:mgmt => {
                           :netmask => '255.255.255.0',
                           :address => '192.168.5.2'
                         },
                         :prod => {
                           :netmask => '255.255.255.0',
                           :address => '192.168.6.2'
                         })
      expect_checks('example2.mgmt.youdevise.com' => '192.168.5.3', 'example2.youdevise.com' => '192.168.6.3')
      thing.allocate_ips_for(spec2)
      thing.remove_ips_for(spec1)[:mgmt].should eql(:netmask => '255.255.255.0', :address => '192.168.5.2')
      thing.remove_ips_for(spec2)[:mgmt].should eql(:netmask => '255.255.255.0', :address => '192.168.5.3')

      File.open("#{dir}/etc/hosts", 'r') { |f| f.read.should eql("") }
    end
  end

  def process_running(pid)
    Process.getpgid(pid)
    true
  rescue Errno::ESRCH
    false
  end

  it 'should hup dnsmasq' do
    Dir.mktmpdir do |dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "\n" }
      response = ""
      pid = fork do
        running = true
        Signal.trap("HUP") do
          running = false
        end
        while running
        end
      end

      process_running(pid).should eql(true)
      File.open("#{dir}/var/run/dnsmasq.pid", 'w') { |f| f.write "#{pid}\n" }
      thing = undertest(dir)
      thing.reload(:mgmt)
      Process.waitpid(pid)
      process_running(pid).should eql(false)
    end
  end

  it 'only allocates an address if the network has been asked for' do
    Dir.mktmpdir do |dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "" }

      thing = undertest(dir)
      spec1 = Provision::Core::MachineSpec.new(
        :hostname => "example",
        :domain => "youdevise.com",
        :aliases => %w(puppet broker),
        :networks => ['noexist']
      )

      expect { thing.allocate_ips_for(spec1) }.
        to raise_exception(Exception, "No networks allocated for this machine, cannot be sane")

      File.open("#{dir}/etc/hosts", 'r') { |f| f.read.should eql("") }
    end
  end

  it 'adds CNAMEs' do
    Dir.mktmpdir do |dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "\n" }
      thing = undertest(dir)

      spec = Provision::Core::MachineSpec.new(
        :hostname => "example",
        :domain => "youdevise.com",
        :cnames => {
          :prod => {
            'cname1' => 'example.youdevise.com'
          }
        },
        :qualified_hostnames => {
          :prod => 'example.youdevise.com',
          :mgmt => 'example.mgmt.youdevise.com'
        }
      )

      expect_checks(
        'example.mgmt.youdevise.com' => '192.168.5.2',
        'example.youdevise.com' => '192.168.6.2'
      )

      expect_cname_checks(
        'cname1.youdevise.com' => 'example.youdevise.com'
      )

      thing.allocate_ips_for(spec)
      thing.add_cnames_for(spec)

      File.open("#{dir}/etc/hosts", 'r') do |f|
        f.read.should eql("\n192.168.5.2 example.mgmt.youdevise.com\n" \
                          "192.168.6.2 example.youdevise.com cname1.youdevise.com\n")
      end
    end
  end
end
