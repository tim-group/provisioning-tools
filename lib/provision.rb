
require 'provision/image/service'
require 'provision/vm/virsh'
require 'provision/vm/descriptor'
require 'provision/core/provisioning_service'

module Provision
  def self.create_provisioning_service()
    configdir = File.join(File.dirname(__FILE__), "../lib/config")
    targetdir = File.join(File.dirname(__FILE__), "../target")

    return provisioning_service = Provision::Core::ProvisioningService.new(
      :image_service=>Provision::Image::Service.new(:configdir=>configdir, :targetdir=>targetdir),
      :vm_service=>Provision::VM::Virsh.new()
    )
  end

  def self.vm(options)
    provisioning_service = Provision.create_provisioning_service()
    provisioning_service.provision_vm(options)
  end
end
