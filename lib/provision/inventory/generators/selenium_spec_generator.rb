require 'provision/inventory/generators/namespace'
require 'provision/inventory/properties'

module Provision::Inventory::Generators::SeleniumSpecGenerator
  def self.extended(base)
    @sel = Provision::Inventory::Properties.new
    @sel.dslvar(:sehub)
    base.add_properties(:selenium,@sel)
  end
end