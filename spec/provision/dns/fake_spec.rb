require 'provision/dns'
require 'provision/dns/fake'

class Provision::DNS::Fake
  def self.set_max_ip(ip)
    @@max_ip = ip
  end
end

describe Provision::DNS::Fake do

  it 'constructs once' do
    Provision::DNS::Fake.set_max_ip(IPAddr.new("192.168.5.1"))
    thing = Provision::DNS.get_backend("Fake")
    ip = thing.allocate_ip_for({})
    ip.to_s.should eql("192.168.5.2")
    other = thing.allocate_ip_for({})
    other.to_s.should eql("192.168.5.3")
  end

  it 'constructs a second time, from same pool of IPs' do
    thing = Provision::DNS.get_backend("Fake")
    ip = thing.allocate_ip_for({})
    ip.to_s.should eql("192.168.5.4")
    other = thing.allocate_ip_for({})
    other.to_s.should eql("192.168.5.5")
  end
end

