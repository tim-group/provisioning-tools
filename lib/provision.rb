
require 'provision/image/service'
require 'provision/vm/virsh'
require 'provision/core/provisioning_service'
require 'provision/workqueue'
require 'provision/dns'
require 'yaml'
require 'pp'

module Provision
  class Config
    def initialize(options={:configfile=>"/etc/provision/config.yaml"})
      @configfile = options[:configfile]
    end

    def required_config_keys
      [:dns_backend, :dns_backend_options, :networks]
    end

    def load()
      return YAML.load(IO.read(@configfile))
    end

    def get()
      config = sym_hash(load())
      missing_keys = required_config_keys - config.keys
      raise "#{@configfile} has missing properties (#{missing_keys.join(', ')})" unless missing_keys.empty?

      return config
    end

    private

    def sym_hash(h)
      n = Hash.new
      h.each { |k, v| n[k.to_sym] = v.is_a?(Hash) ? sym_hash(v) : v }
      n
    end

  end

  def self.base(dir="")
    return File.expand_path(File.join(File.dirname(__FILE__), "../#{dir}"))
  end

  @@config = Config.new()

  def self.home(dir="")
    return File.expand_path(File.join(File.dirname(__FILE__), "../home/#{dir}"))
  end

  def self.config()
   return @@config.get() || {
      :dns_backend => "DNSMasq",
      :dns_backend_options => {},
      :networks => {
         "mgmt" => {
           "net"=>"192.168.5.0/24",
           "start"=>"192.168.5.100"
          },
          "prod" => {
            "net"=>"192.168.6.0/24",
            "start"=>"192.168.6.100"
          }
       }
    }
  end

  def self.numbering_service()
    numbering_service = Provision::DNS.get_backend(self.config()["dns_backend"], self.config()["dns_backend_options"])

    self.config()["networks"].each do |name, net_config|
      numbering_service.add_network(name, net_config["net"], net_config["start"])
    end

    return numbering_service

  end

  def self.create_provisioning_service()
    targetdir = File.join(File.dirname(__FILE__), "../target")

    defaults = self.config()["defaults"]

    return provisioning_service = Provision::Core::ProvisioningService.new(
      :image_service     => Provision::Image::Service.new(
        :configdir => home("image_builders"),
        :targetdir => targetdir
      ),
      :vm_service        => Provision::VM::Virsh.new(),
      :numbering_service => numbering_service,
      :defaults => defaults
    )
  end

  def self.vm(options)
    provisioning_service = Provision.create_provisioning_service()
    provisioning_service.provision_vm(options)
  end

  def self.work_queue(options)
    Provision::WorkQueue.new(
      :listener=>options[:listener],
      :provisioning_service => Provision.create_provisioning_service(),
      :worker_count=> options[:worker_count]
    )
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

