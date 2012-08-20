require 'provision/inventory/namespace'

class Provision::Inventory::Env
  attr_accessor :name
  attr_accessor :host
  attr_accessor :options

  def initialize(name,options,host)
    @name = name
    @host = host
    @options = options
  end

  def add_generator(generator)
    @generators = {} if (@inventory==nil)
    @generators[generator.name] = generator
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

  def get_generator(name)
    return @generators[name]
  end

  def get_generators()
    return @generators.values()
  end
end 
