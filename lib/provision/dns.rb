require 'ipaddr'
require 'provision/namespace'
require 'logger'

module IPAddrExtensions
  def subnet_mask
    return _to_string(@mask_addr)
  end
end

class Provision::DNSNetwork
  attr_reader :logger
  def initialize(name, subnet_string, start_ip, options)
    @name = name
    @subnet = IPAddr.new(subnet_string)
    @subnet.extend(IPAddrExtensions)
    @start_ip = IPAddr.new(start_ip, Socket::AF_INET)
    @logger = options[:logger] || Logger.new(STDERR)
  end
end

class Provision::DNS

  attr_accessor :backend

  def self.get_backend(name, options={})
    raise("get_backend not supplied a name, cannot continue.") if name.nil? or name == false
    require "provision/dns/#{name.downcase}"
    instance = Provision::DNS.const_get(name).new(options)
    instance.backend = name
    instance
  end

  def initialize(options={})
    @networks = {}
    @options = options
    @logger = options[:logger] || Logger.new(STDERR)
  end

  def add_network(name, net, start)
    classname = "#{backend}Network"
    @networks[name] = Provision::DNS.const_get(classname).new(name,net,start,@options)
  end

  def allocate_ips_for(spec)
    allocations = {}

    raise("No networks for this machine, cannot allocate any IPs") if spec[:networks].empty?

    # Should the rest of this allocation loop be folded into the machine spec?
    spec[:networks].each do |network|
      @logger.info("Trying to allocate IP for network #{network}")
      next unless @networks.has_key?(network.to_sym)
      allocations[network] = @networks[network.to_sym].allocate_ip_for(spec)
      @logger.info("Allocated #{allocations[network].to_yaml}")
    end

    raise("No networks allocated for this machine, cannot be sane") if allocations.empty?

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

