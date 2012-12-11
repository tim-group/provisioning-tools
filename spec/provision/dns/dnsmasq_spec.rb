require 'provision/dns'
require 'provision/dns/dnsmasq'
require 'tmpdir'
require 'provision/core/machine_spec'

describe Provision::DNS::DNSMasq do

  it 'constructs once' do
    Dir.mktmpdir {|dir|
      Provision::DNS::DNSMasq.files_dir = dir
      File.open("#{dir}/hosts", 'w') { |f| f.write "# Example hosts file\n127.0.0.1 localhost\n" }
      thing = Provision::DNS.get_backend("DNSMasq")
      ip = thing.allocate_ip_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))
      ip.to_s.should eql("192.168.5.2")
      other = thing.allocate_ip_for(Provision::Core::MachineSpec.new(:hostname => "example2", :domain => "youdevise.com"))
      other.to_s.should eql("192.168.5.3")
      first_again = thing.allocate_ip_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))
      first_again.to_s.should eql("192.168.5.2")

      new_thing = Provision::DNS.get_backend("DNSMasq")
      new_thing_ip = thing.allocate_ip_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))
      new_thing_ip.to_s.should eql("192.168.5.2")
    }
  end
end

