require 'provision/catalogue'
require 'provision/commands'

define "vanillavm" do
  run("configure hostname") {
    hostname = @options[:hostname]
    hostname(hostname)
  }
end