require 'rubygems'
require 'rspec'
require 'provision/vm/virsh'
require 'provision/vm/descriptor'
require 'provision/core/provisioning_service'
require 'provision'
require 'provision/workqueue'
require 'net/ssh'

describe Provision::Core::ProvisioningService do
  def wait_for_vm(ip_address)
    5.times do
     begin
       print "trying #{ip_address}"
       print ssh(ip_address,"uname -a")
       return
     rescue Exception=>e
       print e
     end
     sleep 1
    end
    raise "VM never started"
  end

  def ssh(ip_address, cmd)
    Net::SSH.start(ip_address, 'root', :password => "root", :paranoid => Net::SSH::Verifiers::Null.new) do |ssh|
      return ssh.exec!(cmd).chomp
    end
  end

  before do
    work_queue = Provision.work_queue(:worker_count=>1)
    5.times {|i|
      work_queue.add({:hostname=>"hostname#{i}", :template=>"conventions"})
}
    @build_objects = work_queue.process()
  end

  it 'I can log into all provisioned machines' do

    @build_objects.each do |build|
      print build.to_yaml
      wait_for_vm(build.ip_address())
      ssh(build.ip_address(),'hostname').should eql(build.hostname)
    end
  end

end
