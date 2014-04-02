require 'provision/image/catalogue'
require 'provision/image/commands'

class Provision::Image::Service

  def initialize(options)
    @configdir = options[:configdir]
    @config = options[:config]
    Provision::Image::Catalogue::loadconfig(@configdir)
  end

  def build_image(template, spec)
    Provision::Image::Catalogue.build(template, spec, @config).execute()
  end

  def remove_image(spec)
    raise 'VM marked as non-destroyable' if spec[:disallow_destroy]
    case @config[:vm_storage_type]
    when 'image'
      if File.exist?(spec[:image_path])
        File.delete(spec[:image_path])
      end
    when 'lvm'
      # lvrmeove ..
      if File.exist?("/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}")
        system "lvremove -f /dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      end
    else
      raise "vm_storage_type '#{@config[:vm_storage_type]}' unknown"
    end
  end
end

