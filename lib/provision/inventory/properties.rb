require 'provision/inventory/namespace'

class Provision::Inventory::Properties
  def initialize()
    @hash = {}
  end

  def dslvar(var)
    var_string = var.to_s()
    inst_variable_name = "@#{var_string}".to_sym
    setter = "#{var_string}"
    singleton = class << self; self end
    singleton.send :define_method, setter, lambda { |new_value|
      @hash[var] = new_value
    }
  end

  def each(&block)
    return @hash.each(&block)
  end
end