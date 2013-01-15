require 'provision/vm/namespace'
require 'erb'
require 'ostruct'

class Provision::VM::Virsh
  def initialize()
    @template = "#{Provision.base}/templates/kvm.template"
  end

  def undefine_vm(spec)
    system("virsh undefine #{spec[:hostname]} > /dev/null 2>&1")
  end

  def destroy_vm(spec)
    system("virsh destroy #{spec[:hostname]} > /dev/null 2>&1")
  end

  def start_vm(spec)
    system("virsh start #{spec[:hostname]} > /dev/null 2>&1")
  end

  def define_vm(spec)
    template = ERB.new(File.read(@template))
    to = "#{spec[:libvirt_dir]}/#{spec[:hostname]}.xml"
    begin
      template.result(spec.get_binding())
    rescue Exception=>e
      print e
      print e.backtrace
    end
    File.open to, 'w' do |f|
      f.write template.result(spec.get_binding())
    end
    system("virsh define #{to} > /dev/null 2>&1")
  end
end
