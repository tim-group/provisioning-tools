require 'net/ssh'

describe 'role_router' do

  Spec::Matchers.define :get_responses do
    match do |actual|
      actual=~/1 received/
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

  let(:blah) {"1"}

  it 'can route between networks on different subnets' do

  #  desc.host("puppetmaster-001").nic("mgmt").ip

#    from("dev-puppetmaster-001").pinging(machine("dev-puppetmaster-001").ip("mgmt")).should get_responses()
    from("dev-puppetmaster-001").pinging("dev-puppetmaster-001").should get_responses()
    from("dev-puppetmaster-001").pinging("spaceman").should_not get_responses()
  end

end
