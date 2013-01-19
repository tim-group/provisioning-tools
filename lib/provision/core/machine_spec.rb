require 'provision'
require 'provision/core/namespace'
require 'provision/core/machine_spec'
require 'logger'
require 'digest/sha1'
require 'socket'

class Provision::Core::MachineSpec
  attr_reader :thread_number, :build_dir, :log_dir, :spec

  def initialize(spec)
    @thread_number = spec[:thread_number] || 0
    # FIXME - Should we detect if we're a git checkout or a built / installed gem and change
    #         paths as appropriate?
    @build_dir = spec[:build_dir] || ENV['PROVISIONING_TOOLS_BUILD_DIR'] || "#{Provision.base()}/build"
    #puts "Allocated build dir of #{@build_dir} spec is #{spec[:build_dir]} ENV is #{ENV['PROVISIONING_TOOLS_BUILD_DIR']}"
    Dir.mkdir(@build_dir) if ! File.directory? @build_dir
    @log_dir = spec[:log_dir] || "#{build_dir}/logs"
    Dir.mkdir(@log_dir) if ! File.directory? @log_dir
    @spec = spec
    apply_conventions()
  end

  def apply_conventions()
    if_nil_define_var(:thread_number, 0)
    if_nil_define_var(:images_dir,"#{@spec[:spindle]}")
    if_nil_define_var(:image_path,"#{@spec[:images_dir]}/#{@spec[:hostname]}.img")
    if_nil_define_var(:image_size,"3G")

    if_nil_define_var(:loop0,"loop#{@thread_number*2}")
    if_nil_define_var(:loop1,"loop#{@thread_number*2+1}")

    if_nil_define_var(:console_log,"#{@build_dir}/logs/console-#{@thread_number}.log")
    if_nil_define_var(:temp_dir, "#{@build_dir}/#{@spec[:hostname]}")

    if_nil_define_var(:fqdn,"#{@spec[:hostname]}.#{@spec[:domain]}")

    if_nil_define_var(:vnc_port,"-1")
    if_nil_define_var(:ram,"2097152")

    if_nil_define_var(:networks, ["mgmt","prod"])
    if_nil_define_var(:aptproxy, 'aptproxy.net.local')
    if_nil_define_var(:routes, [])
  end

  def if_nil_define_var(var,value)
    @spec[var] = value if @spec[var]==nil
  end

  def [](key)
    return @spec[key]
  end

  def []=(key,value)
    @spec[key] = value
  end

  def get_binding
    return binding()
  end

  def get_logger(fn)
    Logger.new("#{@log_dir}/#{fn}-#{@thread_number}.log")
  end

  def interfaces()
    nics =[]
    slot = 6
    @spec[:networks].each {|net|
      nics << {
        :slot    => slot,
        :mac     => mac("#{@spec[:fqdn]}.#{net}"),
        :bridge  => "br_#{net}",
        :network => "#{net}"
      }
      slot = slot+1
    }
    nics
  end

  def mac(fqdn = @spec[:fqdn])
    host = Socket.gethostname
    raise 'kvm_mac(): Requires a string type ' +
      'to work with' unless fqdn.is_a?(String)
    raise 'kvm_mac(): An argument given cannot ' +
      'be an empty string value.' if fqdn.empty?
    sha1  = Digest::SHA1.new
    bytes = sha1.digest(fqdn+host)
    "52:54:00:%s" % bytes.unpack('H2x9H2x8H2').join(':')
  end

  def all_hostnames
    hn = [ @spec[:fqdn] ]
    if (!@spec[:aliases].nil?)
      hn << @spec[:aliases].collect {|a| a + '.' + @spec[:domain] }
    end
    hn
  end
end

