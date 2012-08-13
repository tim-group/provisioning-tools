require 'provision/inventory/namespace'
require 'provision/inventory/generator'
require 'provision/inventory/generators/selenium_spec_generator'
require 'provision/inventory/generators/vm_spec_generator'


class Provision::Inventory::Host
  attr_accessor :name
  attr_accessor :spindles

  def add_generator(generator)
    @inventory = {} if (@inventory==nil)
    @inventory[generator.name] = generator
    return generator
  end

  def generator(name, &block)
    generator = Provision::Inventory::Generator.new(name,self)
    generator.instance_eval {
      extend Provision::Inventory::Generators::VMSpecGenerator
      extend Provision::Inventory::Generators::SeleniumSpecGenerator
    }
    generator.instance_eval(&block)
    return add_generator(generator)
  end

  def initialize(name, options)
    @name = name
    @spindles = options[:spindles] || "/mnt"
  end

  def retrieve_specs(key)
    return @inventory[key].generate_specs;
  end

  def spindle()
    @next_spindle = (@next_spindle==nil)?0: @next_spindle+1
    return @spindles[@next_spindle % @spindles.length()]
  end
end
