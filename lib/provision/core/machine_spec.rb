require 'provision/core/machine_spec'

class Provision::Core::MachineSpec
  attr_accessor :spec
  def initialize(spec)
    @spec = spec
    apply_conventions()
  end

  def apply_conventions()
    if_nil_define_var(:thread_number, 0)
    if_nil_define_var(:build_dir,"build") 
    if_nil_define_var(:images_dir,"/images")
    if_nil_define_var(:image_path,"#{@spec[:images_dir]}/#{@spec[:hostname]}.img")
    if_nil_define_var(:image_size,"3G")

    if_nil_define_var(:loop0,"loop#{@spec[:thread_number]*2}")
    if_nil_define_var(:loop1,"loop#{@spec[:thread_number]*2+1}")

    if_nil_define_var(:logdir,"#{@spec[:build_dir]}/logs")
    if_nil_define_var(:console_log,"#{@spec[:build_dir]}/console-#{@spec[:thread_number]}.log")
    if_nil_define_var(:temp_dir,"#{@spec[:build_dir]}")

    if_nil_define_var(:vnc_port,"-1")
    if_nil_define_var(:ram,"512M")
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
end