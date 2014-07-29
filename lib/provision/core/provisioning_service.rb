module Provision::Core
end

require 'logger'
require 'provision/namespace'
require 'provision/core/machine_spec'

class Provision::Core::ProvisioningService
  def initialize(options)
    @vm_service = options[:vm_service] || raise("No :vm_service option passed")
    # FIXME: When old vm_storage_type's go away, uncomment this..
    @storage_service = options[:storage_service] # || raise("No :storage_service option passed")
    @image_service = options[:image_service] || raise("No :image_service option passed")
    @numbering_service = options[:numbering_service] || raise("No :numbering_service option passed")
    @machinespec_defaults = options[:defaults] || {:enc => {:classes => {}}}
    @logger = options[:logger] || Logger.new(STDERR)
  end

  def provision_vm(spec_hash)
    spec_hash = @machinespec_defaults.merge(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)


    if not @vm_service.is_defined(spec_hash)
      @logger.info("Provisioning a newly allocated VM")
      @logger.info("Getting numbering for spec #{spec.inspect}")
      # FIXME - We should pull this step out to a rake task in stacks as per 'free' later..
      spec[:networking] =  @numbering_service.allocate_ips_for(spec)
      @logger.info("Numbering is #{spec[:networking].inspect}")
      @numbering_service.add_cnames_for(spec)
      if @storage_service.nil?
        @image_service.build_image(spec[:template], spec)
        @vm_service.define_vm(spec)
      else
        begin
          @storage_service.create_config(spec[:hostname], spec[:storage])
          storage_xml = @storage_service.spec_to_xml(spec[:hostname])
          @vm_service.define_vm(spec, storage_xml)
          @storage_service.prepare_storage(spec[:hostname], spec[:storage], spec[:temp_dir])
          @image_service.build_image(spec[:template], spec)
          @storage_service.finish_preparing_storage(spec[:hostname], spec[:temp_dir])
        rescue Exception => e
          begin
            @storage_service.cleanup(spec[:hostname])
          ensure
            raise e
          end
        end
      end
      @vm_service.start_vm(spec)
      true
    else
      raise "failed to launch #{spec_hash[:hostname]} already exists"
    end
  end

  def clean_vm(spec_hash)
    spec_hash = @machinespec_defaults.merge(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    @vm_service.destroy_vm(spec) if @vm_service.is_running(spec)

    if @storage_service.nil?
      @image_service.remove_image(spec)
    else
      @storage_service.create_config(spec[:hostname], spec[:storage])
      @storage_service.clean_storage(spec[:hostname], spec[:storage])
    end
    @vm_service.undefine_vm(spec)
    return nil
  end

  def allocate_ip(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    networking = @numbering_service.allocate_ips_for(spec)
    @logger.info("Allocated #{networking.inspect} to #{spec}")
    return networking.values.map { |n| n[:address] }.sort.join(", ")
  end

  def add_cnames(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    @numbering_service.add_cnames_for(spec)
  end

  def remove_cnames(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    @numbering_service.remove_cnames_for(spec)
  end

  def free_ip(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    @numbering_service.remove_ips_for(spec)
    @logger.info("Freed IP address for #{spec.inspect}")
    return nil
  end
end
