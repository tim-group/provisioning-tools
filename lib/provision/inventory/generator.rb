require 'provision/inventory/namespace'

class Provision::Inventory::Generator
  attr_accessor :name
  attr_accessor :properties
  attr_accessor :spindles

  def initialize(name)
    @name = name
    @properties = []
  end

  def basename(basename)
    @basename = basename
  end

  def range(low,high)
    @range_low=low
    @range_high=high
  end

  def template(template)
    @template = template
  end

  def spindles(spindles)
    @spindles = spindles
  end

  def add_properties(symbol, properties)
    @properties << properties
    singleton = class << self; self end
    singleton.send :define_method, symbol, lambda {
      return properties
    }
  end

  def generate_specs
    specs = []
    for i in @range_low..@range_high
      specs<< spec = {:hostname => sprintf("%s-%03d", @basename, i), :template=>@template}
      @properties.each { |bag|
        bag.each {|k,v|
          spec[k]=v
        }
      }
    end
    return specs
  end
end
