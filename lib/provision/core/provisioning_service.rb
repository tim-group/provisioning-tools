module Provision::Core
end

require 'logger'
require 'provision/namespace'
require 'provision/core/machine_spec'

class Provision::Core::ProvisioningService
  def initialize(options)
    @vm_service = options[:vm_service] || raise("No :vm_service option passed")
    @image_service = options[:image_service] || raise("No :image_service option passed")
    @numbering_service = options[:numbering_service] || raise("No :numbering_service option passed")
    @machinespec_defaults = options[:defaults] || {:enc => {:classes => {}}}
    @logger = options[:logger] || Logger.new(STDERR)
  end

  def clean_vm(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    @vm_service.destroy_vm(spec)
    @vm_service.undefine_vm(spec)
    @vm_service.remove_image(spec)
    @numbering_service.remove_ips_for(spec)
  end

  def provision_vm(spec_hash)
    @logger.info("Provisioning a VM")
    spec_hash = @machinespec_defaults.merge(spec_hash)

    clean_vm(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    @logger.info("Getting numbering for spec #{spec.to_yaml}")
    spec[:networking] =  @numbering_service.allocate_ips_for(spec)
    @logger.info("Numbering is #{spec[:networking].to_yaml}")
    @image_service.build_image(spec[:template], spec)
    @vm_service.define_vm(spec)
    @vm_service.start_vm(spec)
  end
end
