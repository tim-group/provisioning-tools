require 'provision/inventory/namespace'
require 'provision/inventory/generator'
require 'provision/inventory/generators/selenium_spec_generator'
require 'provision/inventory/generators/vm_spec_generator'
require 'provision/inventory/env'

class Provision::Inventory::Host
  attr_accessor :name
  attr_accessor :spindles

  def initialize(name, options={})
    @name = name
    @spindles = options[:spindles] || "/mnt"
    @envs = {}
  end

  def env(name,options,&block)    
    @envs[name] = env = Provision::Inventory::Env.new(name,options,self)
    env.instance_eval(&block)
  end

  def get_env(key)
    return @envs[key]
  end

  def get_envs() 
    return @envs.values
  end

  def spindle()
    @next_spindle = (@next_spindle==nil)?0: @next_spindle+1
    return @spindles[@next_spindle % @spindles.length()]
  end
end
