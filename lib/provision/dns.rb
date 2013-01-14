require 'ipaddr'
require 'provision/namespace'

class Provision::DNS
  def self.get_backend(name)
    require "provision/dns/#{name.downcase}"
    classname = "Provision::DNS::#{name}"
    Provision::DNS.const_get(name).new()
  end

  def initialize
    @networks = {}
  end

  def allocate_ips_for(spec)
    allocations = {}

    spec[:networks].each do |network|
      next unless @networks.has_key?(network)
      allocations[network] = @networks[network].allocate_ip_for(spec)
    end

    return allocations
  end

  def remove_ips_for(spec)
    remove_results = {}

    @networks.each do |name, net|
      remove_results[name] = net.remove_ip_for(spec)
    end

    return remove_results
  end

end

