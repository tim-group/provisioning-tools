require 'provision/namespace'

module Provision::Core
end

class Provision::Core::ProvisioningService
  def initialize(options)
    @vm_service = options[:vm_service]
    @image_service = options[:image_service]
  end

  def provision_vm(options)
    vm_descriptor = Provision::VM::Descriptor.new({
      :hostname=>options[:hostname],
      :mac_address => "5e:5d:ee:ff:ff:ee",
      :vnc_port => "-1",
      :ram => "3G",
      :images_dir => "/images",
      :libvirt_dir =>"/var/lib/libvirt/qemu"
    })

    @vm_service.destroy_vm(vm_descriptor.hostname)
    @vm_service.undefine_vm(vm_descriptor.hostname)
    @image_service.build_image(options[:template], options)
    @vm_service.define_vm(vm_descriptor)
    @vm_service.start_vm(vm_descriptor.hostname)
  end
end