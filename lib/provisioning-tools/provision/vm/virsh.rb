require 'provisioning-tools/provision/vm/namespace'
require 'provisioning-tools/provision'
require 'erb'
require 'ostruct'

class Provision::VM::Virsh
  def initialize(config, executor = nil)
    @config = config
    @executor = executor
    @executor = ->(cli) do
      output = `#{cli}`
      fail("Failed to run: #{cli}") unless $CHILD_STATUS.success?
      output
    end if @executor.nil?
  end

  def is_defined(spec)
    is_in_virsh_list(spec, '--all')
  end

  def is_running(spec)
    is_in_virsh_list(spec)
  end

  def is_in_virsh_list(spec, extra = '')
    vm_name = spec[:hostname]
    result = @executor.call("virsh list #{extra} | grep ' #{vm_name} ' | wc -l")
    result.match(/1/)
  end

  def undefine_vm(spec)
    fail 'VM marked as non-destroyable' if spec[:disallow_destroy]
    @executor.call("virsh undefine #{spec[:hostname]} > /dev/null 2>&1")
  end

  def destroy_vm(spec)
    fail 'VM marked as non-destroyable' if spec[:disallow_destroy]
    @executor.call("virsh destroy #{spec[:hostname]} > /dev/null 2>&1")
  end

  def shutdown_vm(spec)
    fail 'VM marked as non-destroyable' if spec[:disallow_destroy]
    @executor.call("virsh shutdown #{spec[:hostname]} > /dev/null 2>&1")
  end

  def shutdown_vm_wait_and_destroy(spec, timeout = 60)
    shutdown_vm(spec)
    begin
      wait_for_shutdown(spec, timeout)
    rescue Exception => e
      destroy_vm(spec)
    end
  end

  def start_vm(spec)
    return if is_running(spec)
    @executor.call("virsh start #{spec[:hostname]} > /dev/null 2>&1")
  end

  def wait_for_shutdown(spec, timeout = 120)
    timeout.times do
      return if !is_running(spec)
      sleep 1
    end

    fail "giving up waiting for #{spec[:hostname]} to shutdown"
  end

  def generate_virsh_xml(spec, storage_xml = nil)
    template_file = if spec[:kvm_template]
                      "#{Provision.templatedir}/#{spec[:kvm_template]}.template"
                    else
                      "#{Provision.templatedir}/kvm.template"
                    end
    template = ERB.new(File.read(template_file))

    binding = VirshBinding.new(spec, @config, storage_xml)
    begin
      template.result(binding.get_binding)
    rescue Exception => e
      print e
      print e.backtrace
      nil
    end
  end

  def write_virsh_xml(spec, storage_xml = nil)
    to = "#{spec[:libvirt_dir]}/#{spec[:hostname]}.xml"
    File.open to, 'w' do |f|
      f.write generate_virsh_xml(spec, storage_xml)
    end
    to
  end

  def define_vm(spec, storage_xml = nil)
    to = write_virsh_xml(spec, storage_xml)
    @executor.call("virsh define #{to} > /dev/null 2>&1")
  end

  def check_vm_definition(spec, storage_xml = nil)
    spec_xml = generate_virsh_xml(spec, storage_xml)
    actual_xml = @executor.call("virsh dumpxml #{spec[:hostname]}")
    fail "actual vm definition differs from spec" unless (spec_xml == actual_xml)
  end
end

class VirshBinding
  attr_accessor :spec, :config, :storage_xml

  def initialize(spec, config, storage_xml = nil)
    @spec = spec
    @config = config
    @storage_xml = storage_xml
  end

  def get_binding
    binding
  end
end
