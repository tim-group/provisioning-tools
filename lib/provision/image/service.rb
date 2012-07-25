require 'provision/image/catalogue'

class Provision::Image::Service
  def initialize(options)
    @configdir = options[:configdir]
    @targetdir = options[:targetdir]
    Provision::Image::Catalogue::load(@configdir)
  end

  def build_image(template, options)
    build =  Provision::Image::Catalogue.build(template, options)
    build.execute()
    return build
  end
end
