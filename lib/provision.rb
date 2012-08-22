require 'provision/image/service'
require 'provision/vm/virsh'
require 'provision/core/provisioning_service'
require 'provision/workqueue'

module Provision
  def self.home(dir)
    configdir = File.join(File.dirname(__FILE__), "../home/#{dir}")
  end

  def self.create_provisioning_service()
    configdir = File.join(File.dirname(__FILE__), "../lib/config")
    targetdir = File.join(File.dirname(__FILE__), "../target")

    return provisioning_service = Provision::Core::ProvisioningService.new(
    :image_service=>Provision::Image::Service.new(:configdir=>home("image_builders"), :targetdir=>targetdir),
    :vm_service=>Provision::VM::Virsh.new()
    )
  end

  def self.vm(options)
    provisioning_service = Provision.create_provisioning_service()
    provisioning_service.provision_vm(options)
  end

  def self.work_queue(options)
    work_queue = Provision::WorkQueue.new(
    :provisioning_service => Provision.create_provisioning_service(),
    :worker_count=> options[:worker_count])
    return work_queue
  end
end
