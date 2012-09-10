require 'provision/inventory/namespace'

class Provision::Inventory::CompositeGenerator

  def initialize(generators, env)
    @generators = generators
    @env = env
  end

  def generate_specs
    specs = []

    @generators.each {|generator|
      generator.generate_specs.each { |spec|
        specs << spec
      }
    }

    return specs
  end
end
