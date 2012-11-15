require 'provision/namespace'
require 'provision/image/build'

module Provision::Image::Catalogue
  @@catalogue = {}

  def load(dir)
    begin
      Dir.entries(dir).each do |file|
        require "#{dir}/#{file}" if file =~/.rb$/
      end
    rescue Exception=>e
      print e
    end
  end

  def list_templates()
    return @@catalogue.keys()
  end

  def define(name, &block)
    @@catalogue[name] = block
  end

  def call_define(name, build)
    closure = @@catalogue[name]
    
    if (closure==nil) 
      raise NameError.new(name)
    end

    build.instance_eval(&closure)
    return build
  end

  def build(name, options)
    build = Provision::Image::Build.new(name, options)
    closure = @@catalogue[name]
    build.instance_eval(&closure)
    return build
  end
end

include Provision::Image::Catalogue
