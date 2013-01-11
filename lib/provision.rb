require 'provision/image/service'
require 'provision/vm/virsh'
require 'provision/core/provisioning_service'
require 'provision/workqueue'
require 'provision/dns'

module Provision
  def self.base(dir="")
    return File.expand_path(File.join(File.dirname(__FILE__), "../#{dir}"))
  end

  def self.loadconfig(file="/etc/provision/config.yaml")
    if File.exists?(file)
      @@config = YAML.load(IO.read(file))
    else
      nil
    end
  end

  def self.home(dir="")
    return File.expand_path(File.join(File.dirname(__FILE__), "../home/#{dir}"))
  end

  def self.config()
    return @@config || {:networks=>{"mgmt" => "192.168.5.0/24",
      "prod" => "192.168.6.0/24"
    }}
  end

  def self.numbering_service()
    numbering_service = Provision::DNS.get_backend("DNSMasq")

    require 'pp'
    self.config()[:networks].each do |name, r|
      pp name
      pp r
    end
    self.config()[:networks].each do |name, range|
      numbering_service.add_network(name, range)
    end

    return numbering_service
  end

  def self.create_provisioning_service()
    targetdir = File.join(File.dirname(__FILE__), "../target")

    return provisioning_service = Provision::Core::ProvisioningService.new(
      :image_service     => Provision::Image::Service.new(
        :configdir => home("image_builders"),
        :targetdir => targetdir
    ),
      :vm_service        => Provision::VM::Virsh.new(),
      :numbering_service => numbering_service
    )
  end

  def self.vm(options)
    provisioning_service = Provision.create_provisioning_service()
    provisioning_service.provision_vm(options)
  end

  def self.work_queue(options)
    work_queue = Provision::WorkQueue.new(
      :listener=>options[:listener],
      :provisioning_service => Provision.create_provisioning_service(),
      :worker_count=> options[:worker_count])
      return work_queue
  end

  def self.create_gold_image(spec_hash)
    spec_hash[:thread_number] = 0
    spec = Provision::Core::MachineSpec.new(spec_hash)
    targetdir = File.join(File.dirname(__FILE__), "../target")
    image_service = Provision::Image::Service.new(:configdir=>home("image_builders"), :targetdir=>targetdir)
    image_service.build_image("ubuntuprecise", spec)
    image_service.build_image("shrink", spec)
  end

end
