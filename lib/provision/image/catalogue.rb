require 'provision/namespace'
require 'provision/image/build'

module Provision::Image::Catalogue
  @@catalogue = {}

  def loadconfig(dir)
    Dir.entries(dir).each do |file|
      require "#{dir}/#{file}" if file =~ /.rb$/
    end
  rescue Exception => e
    print e
  end

  def list_templates
    @@catalogue.keys
  end

  def define(name, &block)
    @@catalogue[name] = block
  end

  def call_define(name, build)
    closure = @@catalogue[name]

    raise NameError.new(name) if closure.nil?

    build.instance_eval(&closure)
    build
  end

  def build(name, options, config)
    build = Provision::Image::Build.new(name, options, config)
    closure = @@catalogue[name]
    raise "attempt to execute a template that is not in the catalogue: #{name}" if closure.nil?
    build.instance_eval(&closure)
    build
  end
end

include Provision::Image::Catalogue
