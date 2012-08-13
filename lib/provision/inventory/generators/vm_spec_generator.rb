require 'provision/inventory/generators/namespace'
require 'provision/inventory/properties'
module Provision::Inventory::Generators::VMSpecGenerator
  def self.extended(base)
    @vm = Provision::Inventory::Properties.new
    @vm.dslvar(:ram)
    @vm.dslvar(:cpus)
    @vm.dslvar(:interfaces)
    base.add_properties(:vm, @vm)
  end
end