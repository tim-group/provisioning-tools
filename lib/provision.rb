require 'provision/namespace'
require 'provision/image/service'
require 'provision/vm/virsh'
require 'provision/core/provisioning_service'
require 'provision/workqueue'
require 'provision/dns'
require 'util/symbol_utils'
require 'yaml'
require 'pp'

module Provision
  def self.base(dir="")
    return File.expand_path(File.join(File.dirname(__FILE__), "../#{dir}"))
  end

  def self.home(dir="")
    return File.expand_path(File.join(File.dirname(__FILE__), "../home/#{dir}"))
  end
end

class Provision::Config
  def initialize(options={})
    @configfile = options[:configfile] || "/etc/provision/config.yaml"
    @symbol_utils = Util::SymbolUtils.new
  end

  def required_config_keys
    [:dns_backend, :dns_backend_options, :networks]
  end

  def get()
    return nil unless File.exists? @configfile
    config = @symbol_utils.symbolize_keys(YAML.load(File.new(@configfile)))
    missing_keys = required_config_keys - config.keys
    raise "#{@configfile} has missing properties (#{missing_keys.join(', ')})" unless missing_keys.empty?

    return config
  end
end

class Provision::Factory
  attr_reader :logger
  def initialize(options={})
    @logger = options[:logger] || Logger.new(STDOUT)
    @config = Provision::Config.new(:configfile => options[:configfile]).get()
  end

  def numbering_service()
    options = @config[:dns_backend_options]
    options[:logger] = @logger
    numbering_service = Provision::DNS.get_backend(@config[:dns_backend], options)

    @config[:networks].each do |name, net_config|
      my_options = options.clone
      ['min', 'max'].each do |type|
        if net_config["#{type}_allocation".to_sym]
          my_options["#{type}_allocation".to_sym] = net_config["#{type}_allocation".to_sym]
        end
      end
      numbering_service.add_network(name, net_config[:net], my_options)
    end

    return numbering_service
  end

  def home(dir="")
    Provision.home(dir)
  end

  def base(dir="")
    Provision.base(dir)
  end

  def virsh
    Provision::VM::Virsh.new(@config)
  end

  def provisioning_service()
    targetdir = File.join(File.dirname(__FILE__), "../target")

    defaults = @config[:defaults]

    @provisioning_service ||= Provision::Core::ProvisioningService.new(
      :image_service => Provision::Image::Service.new(
        :configdir => home("image_builders"),
        :targetdir => targetdir,
        :config => @config
    ),
      :vm_service => virsh,
      :numbering_service => numbering_service,
      :defaults => defaults,
      :logger => @logger
    )
  end

  def work_queue(options)
    logger.info("Building work queue")
    Provision::WorkQueue.new(
      :listener => options[:listener],
      :provisioning_service => provisioning_service(),
      :worker_count => options[:worker_count],
      :logger => logger
    )
  end

  def create_gold_image(spec_hash)
    spec_hash[:thread_number] = 0
    spec = Provision::Core::MachineSpec.new(spec_hash)
    targetdir = File.join(File.dirname(__FILE__), "../target")
    image_service = Provision::Image::Service.new(:configdir => home("image_builders"), :targetdir => targetdir)
    image_service.build_image("ubuntuprecise", spec)
    image_service.build_image("shrink", spec)
  end

  def windows_gold_image(spec_hash, template)
    spec_hash[:thread_number] = 0
    spec = Provision::Core::MachineSpec.new(spec_hash)
    targetdir = File.join(File.dirname(__FILE__), "../target")
    image_service = Provision::Image::Service.new(:configdir => home("image_builders"), :targetdir => targetdir)
    image_service.build_image(template, spec)

    virsh.define_vm(spec)
    puts "starting gold image - prepare for sysprep"
    virsh.start_vm(spec)

    puts "waiting until gold image has shutdown"
    virsh.wait_for_shutdown(spec, 300)

    if not virsh.is_running(spec)
        virsh.undefine_vm(spec)
    end

    puts "gold image build is complete"
  end

end
