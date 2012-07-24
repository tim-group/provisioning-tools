require 'provision/vm/namespace'
require 'erb'
require 'ostruct'

class Provision::VM::Virsh
  def initialize()
    @template = "templates/kvm.template"
  end

  def undefine_vm(hostname)
    system("virsh undefine #{hostname} > /dev/null 2>&1")
  end

  def destroy_vm(hostname)
    system("virsh destroy #{hostname} > /dev/null 2>&1")
  end

  def start_vm(hostname)
    system("virsh start #{hostname} > /dev/null 2>&1")
  end

  def define_vm(vm_descriptor)
    template = ERB.new(File.read(@template))
    to = "#{vm_descriptor.libvirt_dir}/#{vm_descriptor.hostname}.xml"
    File.open to, 'w' do |f|
      f.write template.result(vm_descriptor.get_binding())
    end

    system("virsh define #{to} > /dev/null 2>&1")
  end
end
