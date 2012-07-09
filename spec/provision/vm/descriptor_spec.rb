require 'rubygems'
require 'rspec'
require 'provision/vm/virsh'
require 'provision/vm/descriptor'

describe Provision::VM::Descriptor do
  before do
  end

  it 'derives the mac address from the hostname' do
    NetUtils.lease_file="test/fixtures/leases"

    vm_descriptor = Provision::VM::Descriptor.new(
	    :hostname=>"vmx1",
	    :disk_dir=>"build/",
	    :vnc_port=>9005,
	    :ram => "1G",
	    :images_dir => "build",
	    :libvirt_dir => "build"
    )
    
    vm_descriptor.mac_address.should eql("52:54:00:98:BE:F6")
    vm_descriptor.ip_address.should eql("1.1.1.1")
  end
end
