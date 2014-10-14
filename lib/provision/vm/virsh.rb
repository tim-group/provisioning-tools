require 'provision/vm/namespace'
require 'provision'
require 'erb'
require 'ostruct'

class Provision::VM::Virsh
  def initialize(config)
    @config = config
  end

  def safe_system(cli)
    if system(cli) != true
      raise("Failed to run: #{cli}")
    end
  end

  def is_defined(spec)
    is_in_virsh_list(spec, '--all')
  end

  def is_running(spec)
    is_in_virsh_list(spec)
  end

  def is_in_virsh_list(spec, extra = '')
    vm_name=spec[:hostname]
    result=`virsh list #{extra} | grep ' #{vm_name} ' | wc -l`
    return result.match(/1/)
  end

  def undefine_vm(spec)
    raise 'VM marked as non-destroyable' if spec[:disallow_destroy]
    safe_system("virsh undefine #{spec[:hostname]} > /dev/null 2>&1")
  end

  def destroy_vm(spec)
    raise 'VM marked as non-destroyable' if spec[:disallow_destroy]
    safe_system("virsh destroy #{spec[:hostname]} > /dev/null 2>&1")
  end

  def shutdown_vm(spec)
    raise 'VM marked as non-destroyable' if spec[:disallow_destroy]
    safe_system("virsh shutdown #{spec[:hostname]} > /dev/null 2>&1")
  end

  def shutdown_vm_wait_and_destroy(spec, timeout=60)
    shutdown_vm(spec)
    begin
      wait_for_shutdown(spec, timeout)
    rescue Exception => e
      destroy_vm(spec)
    end
  end

  def start_vm(spec)
    return if is_running(spec)
    safe_system("virsh start #{spec[:hostname]} > /dev/null 2>&1")
  end

  def wait_for_shutdown(spec, timeout = 120)
    timeout.times do
      if not is_running(spec)
        return
      end
      sleep 1
    end

    raise "giving up waiting for #{spec[:hostname]} to shutdown"
  end


  def write_virsh_xml(spec, storage_xml=nil)
    if spec[:kvm_template]
      template_file = "#{Provision.base}/templates/#{spec[:kvm_template]}.template"
    else
      template_file = "#{Provision.base}/templates/kvm.template"
    end
    template = ERB.new(File.read(template_file))
    to = "#{spec[:libvirt_dir]}/#{spec[:hostname]}.xml"
    binding = VirshBinding.new(spec, @config, storage_xml)
    begin
      template.result(binding.get_binding())
    rescue Exception=>e
      print e
      print e.backtrace
    end
    File.open to, 'w' do |f|
      f.write template.result(binding.get_binding())
    end
    to
  end

  def define_vm(spec, storage_xml=nil)
    to = write_virsh_xml(spec, storage_xml)
    safe_system("virsh define #{to} > /dev/null 2>&1")
  end
end

class VirshBinding

  attr_accessor :spec, :config, :storage_xml

  def initialize(spec, config, storage_xml=nil)
    @spec = spec
    @config = config
    @storage_xml = storage_xml
  end

  def get_binding
    return binding()
  end
end



