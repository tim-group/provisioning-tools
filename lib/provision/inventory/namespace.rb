require 'provision/namespace'

module Provision::Inventory
  def self.extended(base)
    base.instance_variable_set("@hosts".to_sym,{})
  end

  def host(name, options, &block)
    @hosts[name] = Host.new(name,options)
    @hosts[name].instance_eval(&block)
  end

  def get_host(key)
    return @hosts[key];
  end
end
