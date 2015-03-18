require 'provision/core/namespace'
require 'provision'
require 'provision/core/machine_spec'
require 'logger'
require 'digest/sha1'
require 'socket'
require 'tmpdir'
require 'fileutils'

class Provision::Core::MachineSpec
  attr_reader :thread_number, :build_dir, :log_dir, :spec

  def initialize(spec)
    @thread_number = spec[:thread_number] || 0
    # FIXME: THIS IS A VALUE OBJECT DONT DO SHIT IN HERE - push it up to the factories
    @build_dir = ENV['PROVISIONING_TOOLS_BUILD_DIR'] || '/tmp/provisioning-tools/build'
    FileUtils.mkdir_p(@build_dir)

    default_log_dir = '/var/log/provisioning-tools'
    if File.directory?(default_log_dir) && File.writable?(default_log_dir)
      @log_dir = default_log_dir
    else
      @log_dir = '/tmp/provisioning-tools/log'
      FileUtils.mkdir_p(@log_dir)
    end

    @spec = spec
    apply_conventions
  end

  def self.spec_for_name(fqdn)
    _, hostname, network, fabric = /([\w-]+)\.(?:(\w+)\.)?([\w-]+)\.net\.local$/.match(fqdn).to_a
    raise "the alleged FQDN '#{fqdn}' must look like <hostname>.[<network>.]<fabric>.net.local" unless _

    suffix = 'net.local'
    if fabric == 'local'
      domain = "dev.#{suffix}"
    else
      domain = "#{fabric}.#{suffix}"
    end
    network ||= 'prod'

    new(
      :hostname => hostname,
      :domain => domain,
      :networks => [network.to_sym],
      :qualified_hostnames => {
        network.to_sym => fqdn
      }
    )
  end

  def apply_conventions
    if_nil_define_var(:thread_number, 0)
    if_nil_define_var(:vm_storage_type, "image")
    if_nil_define_var(:spindle, "/var/local/images")
    if_nil_define_var(:images_dir, "#{@spec[:spindle]}")
    if_nil_define_var(:image_path, "#{@spec[:images_dir]}/#{@spec[:hostname]}.img")
    if_nil_define_var(:lvm_vg, "disk1")
    if_nil_define_var(:image_size, "3G")
    if_nil_define_var(:vcpus, "1")

    if_nil_define_var(:loop0, "loop#{@thread_number * 2}")
    if_nil_define_var(:loop1, "loop#{@thread_number * 2 + 1}")

    if_nil_define_var(:temp_dir, "#{@build_dir}/#{@spec[:hostname]}")

    if @spec.has_key?(:qualified_hostnames)
      if_nil_define_var(:fqdn, "#{@spec[:qualified_hostnames][:mgmt]}")
    end
    if_nil_define_var(:fqdn, "#{@spec[:hostname]}.#{@spec[:domain]}")

    if_nil_define_var(:vnc_port, "-1")
    if_nil_define_var(:ram, "2097152")

    if_nil_define_var(:networks, [:mgmt, :prod])
    if_nil_define_var(:aptproxy, 'aptproxy.net.local')
    if_nil_define_var(:routes, [])
  end

  def if_nil_define_var(var, value)
    @spec[var] = value if @spec[var].nil?
  end

  def [](key)
    @spec[key]
  end

  def []=(key, value)
    @spec[key] = value
  end

  def get_binding
    binding
  end

  def get_logger(fn)
    Logger.new("#{@log_dir}/#{fn}-#{@thread_number}.log", 'weekly')
  end

  def networks
    @spec[:networks]
  end

  def interfaces
    nics = []
    slot = 6
    networks.each do|net|
      nics << {
        :slot => slot,
        :mac => mac("#{@spec[:hostname]}.#{@spec[:domain]}.#{net}"),
        :bridge => "br_#{net}",
        :network => "#{net}"
      }
      slot += 1
    end
    nics
  end

  def hostname_on(network)
    @spec[:qualified_hostnames][network] || raise("unknown network #{network}")
  end

  def domain_on(network)
    @spec[:qualified_hostnames][network].gsub(/^#{@spec[:hostname]}\./, '').strip
  end

  def all_hostnames_on(network)
    hostnames = [hostname_on(network)]
    # the way we do aliases is pretty feeble; these should be per-interface
    if network == :mgmt && !@spec[:aliases].nil?
      hostnames << @spec[:aliases].collect { |a| "#{a}.#{network.to_s}.#{@spec[:domain]}" }
    end
    hostnames
  end

  def mac(fqdn = @spec[:fqdn])
    host = Socket.gethostname
    raise 'a fully-qualified domain name must be a string' unless fqdn.is_a?(String)
    raise 'a fully-qualified domain name cannot be an empty string' if fqdn.empty?
    sha1 = Digest::SHA1.new
    bytes = sha1.digest(fqdn + host)
    "52:54:00:%s" % bytes.unpack('H2x9H2x8H2').join(':')
  end
end
