require 'ipaddr'
require 'provision/namespace'

class Provision::DNS

  attr_accessor :backend

  def self.get_backend(name, options={})
    require "provision/dns/#{name.downcase}"
    instance = Provision::DNS.const_get(name).new(options)
    instance.backend = name
    instance
  end

  def initialize(options={})
    @networks = {}
    @options = options
  end

  def add_network(name, net, start)
    classname = "#{backend}Network"
    @networks[name] = Provision::DNS.const_get(classname).new(net,start,@options)
  end

  def allocate_ips_for(spec)
    allocations = {}

    spec[:networks].each do |network|
      next unless @networks.has_key?(network)
      # probably wrong, and not nice to have to special-case prod here
      if network == 'prod'
        hostname = "#{spec[:hostname]}.#{spec[:domain]}"
      else
        hostname = "#{spec[:hostname]}.#{network}.#{spec[:domain]}"
      end
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

