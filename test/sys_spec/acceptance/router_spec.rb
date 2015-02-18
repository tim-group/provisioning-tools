require 'net/ssh'
require File.dirname(__FILE__) + '/../../../../puppetx/modules/wiring/lib/wiring'

describe 'role_router' do
  include Wiring

  Spec::Matchers.define :get_responses do
    match do |actual|
      actual =~ /1 received/
    end
  end

  class RemoteVerification
    def initialize(from)
      @from = from
    end

    def pinging(host)
      Net::SSH.start(@from, 'root', :password => "root", :paranoid => Net::SSH::Verifiers::Null.new) do |ssh|
        return ssh.exec!("ping -w1 #{host} -c1; echo $?").chomp
      end
    end
  end

  def from(host, &block)
    remote_verification = RemoteVerification.new(host)
  end

  specify do

  end

  let(:blah) { "1" }

  def host(machine)
  ###  return  `dig #{machine}@192.168.5.1 +short`.chomp
    return '192.168.5.239'
  end

  subject {
    platform
  }

  def server(name)
    return subject.find_environment("dev").find_server(name)
  end

  it 'can route between networks on different subnets' do
    from(host("refapp-001")).
  pinging(server("refapp-002").ipaddress).should get_responses()

  #  desc.host("puppetmaster-001").nic("mgmt").ip
#    from("dev-puppetmaster-001").pinging(machine("dev-puppetmaster-001").ip("mgmt")).should get_responses()
#    from(host("dev-puppetmaster-001")).pinging("localhost").should get_responses()
  end

end
