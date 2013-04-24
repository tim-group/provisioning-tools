require 'rubygems'
require 'rspec'
require 'provision'
require 'provision/vm/virsh'
require 'provision/core/machine_spec'
require 'tmpdir'

describe Provision::VM::Virsh do
  before do
  end

  it 'creates a virt machine xml file in libvirt' do
    d = Dir.mktmpdir

    machine_spec = Provision::Core::MachineSpec.new(
      :hostname=>"vmx1",
      :disk_dir=>"build/",
      :vnc_port=>9005,
      :ram => "1G",
      :interfaces => [{:type=>"bridge",:name=>"br0"}, {:type=>"network", :name=>"provnat0"}],
      :images_dir => "build",
      :libvirt_dir => d
    )

    virt_manager = Provision::VM::Virsh.new()
    virt_manager.write_virsh_xml(machine_spec)
    File.exist?("#{d}/vmx1.xml").should eql(true)

    IO.read("#{d}/vmx1.xml").should match("vmx1")
    IO.read("#{d}/vmx1.xml").should match("1G")
    IO.read("#{d}/vmx1.xml").should match("build/vmx1.img")
  end
end
