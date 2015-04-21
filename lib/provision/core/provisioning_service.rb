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
    @machinespec_defaults = options[:defaults] || { :enc => { :classes => {} } }
    @logger = options[:logger] || Logger.new(STDERR)
  end

  def provision_vm(spec_hash, with_numbering = true)
    spec_hash = @machinespec_defaults.merge(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)

    host = `hostname`.strip
    start_time = Time.now

    if !@vm_service.is_defined(spec_hash)
      @logger.info("Provisioning a newly allocated VM")
      @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 01 - starting provision (#{Time.now - start_time} secs)")
      if with_numbering
        @logger.info("Getting numbering for spec #{spec.inspect}")
        # FIXME - We should pull this step out to a rake task in stacks as per 'free' later..
        spec[:networking] =  @numbering_service.allocate_ips_for(spec)
        @logger.info("Numbering is #{spec[:networking].inspect}")
        @numbering_service.add_cnames_for(spec)
      end
      if @storage_service.nil?
        @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 02a - building image (#{Time.now - start_time} secs)")
        @image_service.build_image(spec[:template], spec)
        @vm_service.define_vm(spec)
      else
        begin
          @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 01b1 - storage prep (#{Time.now - start_time} secs)")
          @storage_service.create_config(spec[:hostname], spec[:storage])
          storage_xml = @storage_service.spec_to_xml(spec[:hostname])
          @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 01b2 - storage prep (#{Time.now - start_time} secs)")
          @vm_service.define_vm(spec, storage_xml)
          @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 01b3 - storage prep (#{Time.now - start_time} secs)")
          @storage_service.prepare_storage(spec[:hostname], spec[:temp_dir])

          # FIXME:
          # Need to get some storage things into the spec, can't do it where spec
          # is created above because that stuff knows nothing about storage..
          @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 01b4 - storage prep (#{Time.now - start_time} secs)")
          spec[:host_device] = @storage_service.get_host_device(spec[:hostname], '/'.to_sym)
          @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 01b5 - storage prep (#{Time.now - start_time} secs)")
          spec[:host_device_partition] = "/dev/mapper/#{@storage_service.get_host_device_partition(spec[:hostname],
                                                                                                   '/'.to_sym)}"
          # end FIXME

          @logger.debug("calling build image")
          @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 02b - building image (#{Time.now - start_time} secs)")
          @image_service.build_image(spec[:template], spec)
          @storage_service.finish_preparing_storage(spec[:hostname], spec[:temp_dir])
        rescue Exception => e
          begin
            @storage_service.cleanup(spec[:hostname])
          rescue Exception => f
            @logger.debug("Problem occurred during cleanup, exception was: #{f.inspect}")
          ensure
            raise e
          end
        end
      end
      unless spec[:dont_start]
        @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 03 - starting vm (#{Time.now - start_time} secs)")
        @vm_service.start_vm(spec)
      end
      unless spec[:wait_for_shutdown].nil?
        if spec[:wait_for_shutdown] == true
          @vm_service.wait_for_shutdown(spec)
        else
          @vm_service.wait_for_shutdown(spec, spec[:wait_for_shutdown])
        end
      end
      @logger.info("#{Time.now}: #{host}: #{spec[:hostname]}: 04 - end provision (#{Time.now - start_time} secs)")
      true
    else
      raise "failed to launch #{spec_hash[:hostname]} already exists"
    end
  end

  def clean_vm(spec_hash)
    spec_hash = @machinespec_defaults.merge(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    @vm_service.shutdown_vm_wait_and_destroy(spec) if @vm_service.is_running(spec)

    if @storage_service.nil?
      @image_service.remove_image(spec)
    else
      @storage_service.create_config(spec[:hostname], spec[:storage])
      @storage_service.remove_storage(spec[:hostname])
    end
    @vm_service.undefine_vm(spec)
    nil
  end

  def allocate_ip(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    networking = @numbering_service.allocate_ips_for(spec)
    @logger.info("Allocated #{networking.inspect} to #{spec}")
    networking.values.map { |n| n[:address] }.sort.join(", ")
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
    nil
  end
end
