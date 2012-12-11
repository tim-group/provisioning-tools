require 'ipaddr'

class Provision::DNS
  def self.get_backend(name)
    require "provision/dns/#{name.downcase}"
    classname = "Provision::DNS::#{name}"
    Provision::DNS.const_get(name).new()
  end
end

