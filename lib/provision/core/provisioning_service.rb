require 'provision/namespace'

module Provision::Core
end

class Provision::Core::ProvisioningService
  def initialize(options)
    @vm_service = options[:vm_service]
    @image_service = options[:image_service]
  end

  def provision_vm(spec)
    @vm_service.destroy_vm(spec[:hostname])
    @vm_service.undefine_vm(spec[:hostname])
    @image_service.build_image(spec[:template], spec)
    @vm_service.define_vm(spec)
    @vm_service.start_vm(spec[:hostname])
  end
end