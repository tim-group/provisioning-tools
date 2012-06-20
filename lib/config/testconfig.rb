require 'provision/catalogue'
require 'provision/commands'

define "vanillavm" do
  ubuntuprecise
  run("configure hostname") {
  }
end