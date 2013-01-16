require 'ipaddr'
require 'provision/namespace'

class Provision::DNS
  def self.get_backend(name, options={})
    require "provision/dns/#{name.downcase}"
    classname = "Provision::DNS::#{name}"
    Provision::DNS.const_get(name).new(options)
  end

  def initialize(options={})
    @networks = {}
  end

  def allocate_ips_for(spec)
    allocations = {}

    spec[:networks].each do |network|
      next unless @networks.has_key?(network)
      hostname = "#{spec[:hostname]}.#{network}.#{spec[:domain]}" # probably wrong
      mac = spec.interfaces[0][:mac]
      all_hostnames = spec.all_hostnames
      allocations[network] = @networks[network].allocate_ip_for(hostname, all_hostnames, network, mac)
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

