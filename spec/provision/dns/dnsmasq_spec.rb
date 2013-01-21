require 'provision/dns'
require 'provision/dns/dnsmasq'
require 'tmpdir'
require 'provision/core/machine_spec'

class Provision::DNS::DNSMasq
  def max_ip(network)
    @networks[network].max_ip.to_s
  end
  def hosts_by_name(network)
    @networks[network].by_name
  end
end

describe Provision::DNS::DNSMasq do

  def mksubdirs(dir)
    Dir.mkdir("#{dir}/etc")
    Dir.mkdir("#{dir}/var")
    Dir.mkdir("#{dir}/var/run")
  end

  def undertest(dir)
    Provision::DNS::DNSMasq.files_dir = dir
    dnsmasq = Provision::DNS.get_backend("DNSMasq")
    dnsmasq.add_network("mgmt", "192.168.5.0/24", "192.168.5.1")
    return dnsmasq
  end

  it 'constructs once' do
    Dir.mktmpdir {|dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "# Example hosts file\n127.0.0.1 localhost\n" }
      thing = undertest(dir)
      ip = thing.allocate_ips_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))["mgmt"][:address]
      ip.kind_of?(IPAddr).should eql(false)
      ip.to_s.should eql("192.168.5.2")
      other = thing.allocate_ips_for(Provision::Core::MachineSpec.new(:hostname => "example2", :domain => "youdevise.com"))["mgmt"][:address]
      other.to_s.should eql("192.168.5.3")
      first_again = thing.allocate_ips_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))["mgmt"][:address]

      first_again.to_s.should eql("192.168.5.2")

      new_thing = undertest(dir)
      new_thing_ip = new_thing.allocate_ips_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))["mgmt"][:address]
      new_thing_ip.to_s.should eql("192.168.5.2")

      new_thing.max_ip('mgmt').should eql("192.168.5.3")
      new_thing.hosts_by_name('mgmt').should eql({
        "example.mgmt.youdevise.com" => "192.168.5.2",
        "example.youdevise.com" => "192.168.5.2",
        "example2.mgmt.youdevise.com" => "192.168.5.3",
        "example2.youdevise.com" => "192.168.5.3"
      })
    }
  end

  it 'parses wacky /etc/hosts' do
    Dir.mktmpdir {|dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "192.168.5.5\t    fnar fnar.example.com\n192.168.5.2   \t boo.example.com\tboo   \n# Example hosts file\n192.168.5.1 flib   \n" }
      thing = undertest(dir)
      thing.hosts_by_name('mgmt').should eql({
        "fnar" => "192.168.5.5",
        "fnar.example.com" => "192.168.5.5",
        "boo.example.com" => "192.168.5.2",
        "boo" => "192.168.5.2",
        "flib" => "192.168.5.1"
      })
      thing.max_ip('mgmt').should eql("192.168.5.5")
    }
  end

  it 'writes hosts and ethers out' do
    Dir.mktmpdir {|dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "\n" }
      thing = undertest(dir)
      thing.allocate_ips_for(
        Provision::Core::MachineSpec.new(
          :hostname => "example",
          :domain   => "youdevise.com",
          :aliases  => ["puppet", "broker"]
        )
      )

      sha1  = Digest::SHA1.new
      bytes = sha1.digest("example.youdevise.com.mgmt"+Socket.gethostname)
      mac = "52:54:00:%s" % bytes.unpack('H2x9H2x8H2').join(':')

      File.open("#{dir}/etc/ethers", 'r') {
        |f| f.read.should eql("#{mac} 192.168.5.2\n") }
        File.open("#{dir}/etc/hosts", 'r') { |f| f.read.should eql("\n192.168.5.2 example.mgmt.youdevise.com example.youdevise.com puppet.youdevise.com broker.youdevise.com\n") }
    }
  end

  it 'removes entries from hosts and ethers file' do
    Dir.mktmpdir {|dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "" }
      File.open("#{dir}/etc/ethers", 'w') { |f| f.write "" }
      thing = undertest(dir)
      spec1 = Provision::Core::MachineSpec.new(
        :hostname => "example",
        :domain   => "youdevise.com",
        :aliases  => ["puppet", "broker"]
      )
      spec2 = Provision::Core::MachineSpec.new(
        :hostname => "example2",
        :domain   => "youdevise.com",
        :aliases  => ["puppet", "broker"]
      )
      require 'yaml'
      ip_spec = thing.allocate_ips_for(spec1)
      ip_spec.should eql({
        "mgmt" => {
          :netmask => '255.255.255.0',
          :address => '192.168.5.2'
        }
      })
      thing.allocate_ips_for(spec2)
      thing.remove_ips_for(spec1)['mgmt'].should eql true
      thing.remove_ips_for(spec2)['mgmt'].should eql true

      File.open("#{dir}/etc/ethers", 'r') { |f| f.read.should eql("") }
      File.open("#{dir}/etc/hosts", 'r') { |f| f.read.should eql("") }
    }
  end
  def process_running(pid)
    begin
      Process.getpgid(pid)
      true
    rescue Errno::ESRCH
      false
    end
  end

  it 'should hup dnsmasq' do
    Dir.mktmpdir {|dir|
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

      process_running(pid).should eql true
      File.open("#{dir}/var/run/dnsmasq.pid", 'w') { |f| f.write "#{pid}\n" }
      thing = undertest(dir)
      thing.reload_dnsmasq()
      Process.waitpid(pid)
      process_running(pid).should eql false
    }

  end

  it 'only allocates an address if the network has been asked for' do
    Dir.mktmpdir {|dir|
      mksubdirs(dir)
      File.open("#{dir}/etc/hosts", 'w') { |f| f.write "" }
      File.open("#{dir}/etc/ethers", 'w') { |f| f.write "" }

      thing = undertest(dir)
      spec1 = Provision::Core::MachineSpec.new(
        :hostname => "example",
        :domain   => "youdevise.com",
        :aliases  => ["puppet", "broker"],
        :networks => ['noexist']
      )

      thing.allocate_ips_for(spec1).should eql({})

      File.open("#{dir}/etc/ethers", 'r') { |f| f.read.should eql("") }
      File.open("#{dir}/etc/hosts", 'r') { |f| f.read.should eql("") }
    }
  end
end

