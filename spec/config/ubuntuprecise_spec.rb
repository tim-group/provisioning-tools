require 'provision'
require 'net/ssh'

describe Provision do
  it 'after building a test vm I am able to login' do
    Provision.vm(:hostname=>"RANDOMX", :template=>"ubuntuprecise")

    leasefile = "/tmp/my.lease"
    macaddress = "5e:5d:ee:ff:ff:ee"

    cmd = "cat #{leasefile} | grep #{macaddress} | awk '{print $3}'"

    ipaddress = `#{cmd}`.chomp

    print "IPADDR: #{ipaddress}\n"
    sleep 5

    hostname = nil
    Net::SSH.start(ipaddress, 'root', :password => "root", :paranoid => Net::SSH::Verifiers::Null.new) do |ssh|
      hostname = ssh.exec!("hostname").chomp
      print ssh.exec("ip addr")
    end

    hostname.should eql("RANDOMX")
  end

  it 'after building a test vm I can verify the host is the one I specified'
end
