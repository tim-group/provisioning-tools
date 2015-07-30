require 'provisioning-tools/provision/namespace'
require 'provisioning-tools/provision/image/service'
require 'provisioning-tools/provision/vm/virsh'
require 'provisioning-tools/provision/core/provisioning_service'
require 'provisioning-tools/provision/workqueue'
require 'provisioning-tools/provision/dns'
require 'provisioning-tools/provision/storage'
require 'provisioning-tools/provision/storage/service'
require 'provisioning-tools/util/symbol_utils'
require 'yaml'

module Provision
  def self.homedir
    File.expand_path(File.join(File.dirname(__FILE__), '/home/image_builders/'))
  end

  def self.templatedir
    File.expand_path(File.join(File.dirname(__FILE__), '/templates/'))
  end
end

class Provision::Config
  def initialize(options = {})
    @configfile = options[:configfile] || "/etc/provision/config.yaml"
    @symbol_utils = Util::SymbolUtils.new
  end

  def required_config_keys
    [:dns_backend, :dns_backend_options, :networks]
  end

  def get
    return nil unless File.exists? @configfile
    config = @symbol_utils.symbolize_keys(YAML.load(File.new(@configfile)))
    # FIXME: Once new code is everywhere, undo this conditional
    # and move :storage into the required_config_keys method
    missing_keys = required_config_keys
    missing_keys << :storage if config[:vm_storage_type] == 'new'
    missing_keys -= config.keys
    fail "#{@configfile} has missing properties (#{missing_keys.join(', ')})" unless missing_keys.empty?

    config
  end
end

class Provision::Factory
  attr_reader :logger
  def initialize(options = {})
    @logger = options[:logger] || Logger.new(STDOUT)
    @config = Provision::Config.new(:configfile => options[:configfile]).get
  end

  def numbering_service
    options = @config[:dns_backend_options]
    options[:logger] = @logger
    numbering_service = Provision::DNS.get_backend(@config[:dns_backend], options)

    @config[:networks].each do |name, net_config|
      my_options = options.clone
      my_options.merge!(
        net_config.reject do |key, _value|
          key == :net
        end
      )
      numbering_service.add_network(name, net_config[:net], my_options)
    end

    numbering_service
  end

  def virsh
    Provision::VM::Virsh.new(@config)
  end

  def provisioning_service
    targetdir = File.join(File.dirname(__FILE__), "../target")

    if !defined?(@config[:defaults])
      puts "@config[:defaults] is undefined, are you sure this is a compute node?"
      exit 1
    end

    defaults = @config[:defaults]

    storage_service = nil
    if @config[:vm_storage_type] == 'new'
      storage_service = Provision::Storage::Service.new(@config[:storage])
    end

    @provisioning_service ||= Provision::Core::ProvisioningService.new(
      :image_service => Provision::Image::Service.new(
        :homedir => Provision.homedir,
        :config => @config
      ),
      :storage_service => storage_service,
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
      :provisioning_service => provisioning_service,
      :worker_count => options[:worker_count],
      :logger => logger
    )
  end

  def create_gold_image(spec_hash)
    spec_hash[:thread_number] = 0
    distid = spec_hash[:distid] || 'ubuntu'
    distcodename = spec_hash[:distcodename] || 'precise'
    spec = Provision::Core::MachineSpec.new(spec_hash)
    targetdir = File.join(File.dirname(__FILE__), "../target")
    image_service = Provision::Image::Service.new(:config => @config)
    image_service.build_image("gold-#{distid}-#{distcodename}", spec)
    image_service.build_image("shrink", spec)
  end
end
