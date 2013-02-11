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

    if !options[:configfile].nil?
      @config = Provision::Config.new(:configfile => options[:configfile]).get()
    end
  end

  def numbering_service()
    options = @config[:dns_backend_options]
    options[:logger] = @logger
    numbering_service = Provision::DNS.get_backend(@config[:dns_backend], options)

    logger.info("Making networks for numbering service: #{@config[:networks].to_yaml}")
    @config[:networks].each do |name, net_config|
      numbering_service.add_network(name, net_config[:net], net_config[:start])
    end

    return numbering_service
  end

  def home(dir="")
    Provision.home(dir)
  end

  def base(dir="")
    Provision.base(dir)
  end

  def provisioning_service()
    targetdir = File.join(File.dirname(__FILE__), "../target")

    defaults = @config[:defaults]

    @provisioning_service ||= Provision::Core::ProvisioningService.new(
      :image_service => Provision::Image::Service.new(
        :configdir => home("image_builders"),
        :targetdir => targetdir
      ),
      :vm_service => Provision::VM::Virsh.new(),
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
end
