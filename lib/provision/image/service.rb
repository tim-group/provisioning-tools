require 'provision/image/catalogue'

class Provision::Image::Service
  def initialize(options)
    @configdir = options[:configdir]
    Provision::Image::Catalogue::loadconfig(@configdir)
  end

  def build_image(template, options)
    Provision::Image::Catalogue.build(template, options).execute()
  end

  def remove_image(spec)
    if File.exist?(spec[:image_path])
      File.delete(spec[:image_path])
    end
  end
end

