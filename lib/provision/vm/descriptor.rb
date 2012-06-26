require 'provision/vm/namespace'

class Provision::VM::Descriptor
  attr_accessor :hostname
  attr_accessor :mac_address
  attr_accessor :vnc_port
  attr_accessor :ram
  attr_accessor :image_path
  attr_accessor :libvirt_dir
  
  def initialize(options)
    @hostname = options[:hostname]
    @mac_address = options[:mac_address]
    @vnc_port = options[:vnc_port]
    @ram = options[:ram]
    @images_dir = options[:images_dir]
    @image_path = "#{@images_dir}/#{@hostname}.img"
    @libvirt_dir = options[:libvirt_dir]
  end

  def get_binding
    return binding()
  end
end