require 'provision'
require 'provision/core/namespace'
require 'provision/core/machine_spec'
require 'provision/vm/netutils'
require 'logger'

class Provision::Core::MachineSpec
  include Provision::VM::NetUtils
  attr_accessor :spec
  attr_reader :thread_number, :build_dir, :log_dir

  def initialize(spec)
    @thread_number = spec[:thread_number] || 0
    b_d = spec[:build_dir] || 'build'
    @build_dir = "#{Provision.base()}/#{b_d}"
    @log_dir = spec[:log_dir] || "#{build_dir}/logs"
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

    @spec[:networks] = ["mgmt","prod"]
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
end

