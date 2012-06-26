require 'rubygems'
require 'rspec'
require 'provision/vm/virsh'
require 'provision/vm/descriptor'

describe Provision::VM::Virsh do
  before do
  end

  it 'creates a virt machine xml file in libvirt' do
    virt_manager = Provision::VM::Virsh.new()
    vm_descriptor = Provision::VM::Descriptor.new(
    :hostname=>"vmx1",
    :disk_dir=>"build/mnt4/",
    :vnc_port=>9005,
    :ram => "1G",
    :images_dir => "build",
    :libvirt_dir => "build"
    )

    virt_manager.define_vm(vm_descriptor)
    File.exist?("build/vmx1.xml").should eql(true)
  end
end