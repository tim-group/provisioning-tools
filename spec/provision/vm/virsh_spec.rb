require 'provisioning-tools/provision'
require 'provisioning-tools/provision/vm/virsh'
require 'provisioning-tools/provision/core/machine_spec'
require 'tmpdir'

describe Provision::VM::Virsh do
  before do
  end

  it 'creates a virt machine xml file in libvirt' do
    d = Dir.mktmpdir

    machine_spec = Provision::Core::MachineSpec.new(
      :hostname => "vmx1",
      :disk_dir => "build/",
      :vnc_port => 9005,
      :ram => "1G",
      :interfaces => [{ :type => "bridge", :name => "br0" }, { :type => "network", :name => "provnat0" }],
      :images_dir => "build",
      :libvirt_dir => d
    )

    virt_manager = Provision::VM::Virsh.new(:vm_storage_type => "image")
    fn = virt_manager.write_virsh_xml(machine_spec)
    fn.should eql("#{d}/vmx1.xml")
    File.exist?("#{d}/vmx1.xml").should eql(true)

    IO.read("#{d}/vmx1.xml").should match("vmx1")
    IO.read("#{d}/vmx1.xml").should match("1G")
    IO.read("#{d}/vmx1.xml").should match("build/vmx1.img")
  end

  it 'creates a virt machine xml file in libvirt with lvm support' do
    d = Dir.mktmpdir

    machine_spec = Provision::Core::MachineSpec.new(
      :hostname => "vmx-1",
      :disk_dir => "build/",
      :vnc_port => 9005,
      :ram => "1G",
      :interfaces => [{ :type => "bridge", :name => "br0" }, { :type => "network", :name => "provnat0" }],
      :images_dir => "build",
      :libvirt_dir => d
    )

    config = {
      :vm_storage_type => 'lvm'
    }
    virt_manager = Provision::VM::Virsh.new(config)
    fn = virt_manager.write_virsh_xml(machine_spec)
    fn.should eql("#{d}/vmx-1.xml")
    File.exist?("#{d}/vmx-1.xml").should eql(true)

    IO.read("#{d}/vmx-1.xml").should match("<name>vmx-1</name>")
    IO.read("#{d}/vmx-1.xml").should match("<source dev='/dev/disk1/vmx-1'/>")
    IO.read("#{d}/vmx-1.xml").should match("<target dev='vda' bus='virtio'/>")
  end

  it 'creates a virt machine xml file in libvirt with a different format template' do
    d = Dir.mktmpdir

    machine_spec = Provision::Core::MachineSpec.new(
      :hostname => "vmx-1",
      :disk_dir => "build/",
      :vnc_port => 9005,
      :ram => "1G",
      :interfaces => [{ :type => "bridge", :name => "br0" }, { :type => "network", :name => "provnat0" }],
      :images_dir => "build",
      :libvirt_dir => d,
      :kvm_template => 'kvm_no_virtio'
    )

    config = {
      :vm_storage_type => 'lvm'
    }
    virt_manager = Provision::VM::Virsh.new(config)
    fn = virt_manager.write_virsh_xml(machine_spec)
    fn.should eql("#{d}/vmx-1.xml")
    File.exist?("#{d}/vmx-1.xml").should eql(true)

    IO.read("#{d}/vmx-1.xml").should match("<name>vmx-1</name>")
    IO.read("#{d}/vmx-1.xml").should match("<source dev='/dev/disk1/vmx-1'/>")
    IO.read("#{d}/vmx-1.xml").should match("<target dev='hda' bus='ide'/>")
    IO.read("#{d}/vmx-1.xml").should_not match("<model type='virtio'/>")
  end

  it 'destroys VM when disallow_destroy is not set' do
    hostname = 'somevmtobedestroyed'
    spec = { :hostname => hostname }

    system_calls = []
    virt_manager = Provision::VM::Virsh.new({}, ->(cli) { system_calls.push(cli) })

    virt_manager.destroy_vm(spec)
    system_calls.should eql(["virsh destroy #{hostname} > /dev/null 2>&1"])
  end

  it 'does not destroy VM when disallow_destroy is set' do
    hostname = 'somevmtobedestroyed'
    spec = { :disallow_destroy => true, :hostname => hostname }

    system_calls = []
    virt_manager = Provision::VM::Virsh.new({}, ->(cli) { system_calls.push(cli) })

    expect do
      virt_manager.destroy_vm(spec)
    end.to raise_error("VM marked as non-destroyable")

    system_calls.should eql([])
  end

  it 'undefine VM when disallow_destroy is not set' do
    hostname = 'somevmtobedestroyed'
    spec = { :hostname => hostname }

    system_calls = []
    virt_manager = Provision::VM::Virsh.new({}, ->(cli) { system_calls.push(cli) })

    virt_manager.undefine_vm(spec)
    system_calls.should eql(["virsh undefine #{hostname} > /dev/null 2>&1"])
  end

  it 'does not undefine VM when disallow_destroy is set' do
    hostname = 'somevmtobedestroyed'
    spec = { :disallow_destroy => true, :hostname => hostname }

    system_calls = []
    virt_manager = Provision::VM::Virsh.new({}, ->(cli) { system_calls.push(cli) })

    expect do
      virt_manager.undefine_vm(spec)
    end.to raise_error("VM marked as non-destroyable")

    system_calls.should eql([])
  end

  it 'reports if actual vm definition differs from spec' do
    d = Dir.mktmpdir

    machine_spec = Provision::Core::MachineSpec.new(
      :hostname => "vmx-1",
      :disk_dir => "build/",
      :vnc_port => 9005,
      :ram => "1G",
      :interfaces => [{ :type => "bridge", :name => "br0" }, { :type => "network", :name => "provnat0" }],
      :images_dir => "build",
      :libvirt_dir => d
    )

    config = {
      :vm_storage_type => 'lvm'
    }

    system_calls = []
    executor = ->(cli) do
      system_calls.push(cli)
      return "<xml/>"
    end
    virt_manager = Provision::VM::Virsh.new(config, executor)

    expect do
      virt_manager.check_vm_definition(machine_spec)
    end.to raise_error("actual vm definition differs from spec")
    system_calls.should eql(["virsh dumpxml vmx-1"])
  end

  xit 'passes checks if actual vm definition equals spec' do
    d = Dir.mktmpdir

    machine_spec = Provision::Core::MachineSpec.new(
      :hostname => "vmx-1",
      :disk_dir => "build/",
      :vnc_port => 9005,
      :ram => "1G",
      :interfaces => [{ :type => "bridge", :name => "br0" }, { :type => "network", :name => "provnat0" }],
      :images_dir => "build",
      :libvirt_dir => d
    )

    config = {
      :vm_storage_type => 'lvm'
    }

    expected = File.open(File.join(File.dirname(__FILE__), "expected.xml")).read

    system_calls = []
    executor = ->(cli) do
      system_calls.push(cli)
      return expected
    end
    virt_manager = Provision::VM::Virsh.new(config, executor)

    virt_manager.check_vm_definition(machine_spec)
    system_calls.should eql(["virsh dumpxml vmx-1"])
  end
end
