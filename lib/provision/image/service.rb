require 'provision/image/catalogue'
require 'provision/image/commands'

class Provision::Image::Service
  def initialize(options)
    @configdir = options[:configdir]
    Provision::Image::Catalogue::loadconfig(@configdir)
  end

  def build_image(template, options)
    Provision::Image::Catalogue.build(template, options).execute()
  end

  def remove_image(spec)
    case spec[:vm_storage_type]
    when 'image'
      if File.exist?(spec[:image_path])
        File.delete(spec[:image_path])
      end
    when 'lvm'
      # lvrmeove ..
      if File.exist?("/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}")
        cmd "lvremove -f /dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      end
    end
  end
end

