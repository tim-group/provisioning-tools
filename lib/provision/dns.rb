require 'ipaddr'
require 'provision/namespace'
require 'logger'
require 'yaml'

module IPAddrExtensions
  def subnet_mask
    return _to_string(@mask_addr)
  end
end

class Provision::DNSNetwork
  attr_reader :logger

  def initialize(name, range, options)
    @name = name
    @subnet = IPAddr.new(range)
    @subnet.extend(IPAddrExtensions)
    @logger = options[:logger] || Logger.new(STDERR)

    parts = range.split('/')
    if parts.size != 2
      raise(":network_range must be of the format X.X.X.X/Y")
    end
    broadcast_mask = (IPAddr::IN4MASK >> parts[1].to_i)
    @subnet_mask = IPAddr.new(IPAddr::IN4MASK ^ broadcast_mask, Socket::AF_INET)
    @network = IPAddr.new(parts[0]).mask(parts[1])
    @broadcast = @network | IPAddr.new(broadcast_mask, Socket::AF_INET)

    min_allocation = options[:min_allocation] ||  @network.to_i + 10
    @min_allocation = IPAddr.new(min_allocation, Socket::AF_INET)

    max_allocation = options[:max_allocation] || @broadcast.to_i - 1
    @max_allocation = IPAddr.new(max_allocation, Socket::AF_INET)

  end

  def lookup_ip_for(fqdn)
     resolver = Resolv::DNS.new(
       :nameserver => get_primary_nameserver,
       :search => [],
       :ndots => 1
     )

     begin
       IPAddr.new(resolver.getaddress(fqdn).to_s, Socket::AF_INET)
     rescue Resolv::ResolvError
       puts "Could not find #{fqdn}"
       false
     end
  end

  def hostname_from_spec(spec)
     spec.hostname_on(@name)
  end

  def allocate_ip_for(spec)
     hostname = hostname_from_spec spec
     ip = nil

     if lookup_ip_for(hostname)
       puts "No new allocation for #{hostname}, already allocated"
       return {
         :netmask => @subnet_mask.to_s,
         :address => lookup_ip_for(hostname)
       }
     else

       max_ip = @max_allocation
       ip = @min_allocation
       while !try_add_reverse_lookup(ip, hostname)
         ip = IPAddr.new(ip.to_i + 1, Socket::AF_INET)
         if ip >= max_ip
           raise("Ran out of ips")
         end
       end
       add_forward_lookup(ip, hostname)
     end
     sleep 2 # Avoid race conditions with re-reading from a DNS slave which has not updated
     {
       :netmask => @subnet_mask.to_s,
       :address => ip
     }
  end

  def remove_ip_for(spec)
     hostname = hostname_from_spec spec
     ip = lookup_ip_for(hostname)
     if ip
       remove_forward_lookup(hostname)
       remove_reverse_lookup ip
     end

     return {
       :netmask => @subnet_mask.to_s,
       :address => ip
     }
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

  def add_network(name, range, options)
    classname = "#{backend}Network"
    @networks[name] = Provision::DNS.const_get(classname).new(name, range, options)
  end

  def allocate_ips_for(spec)
    allocations = {}

    raise("No networks for this machine, cannot allocate any IPs") if spec.networks.empty?

    # Should the rest of this allocation loop be folded into the machine spec?
    spec.networks.each do |network_name|
      network = network_name.to_sym
      @logger.info("Trying to allocate IP for network #{network}")
      next unless @networks.has_key?(network)
      allocations[network] = @networks[network].allocate_ip_for(spec)
      @logger.info("Allocated #{allocations[network][:address]}")
    end

    raise("No networks allocated for this machine, cannot be sane") if allocations.empty?

    return allocations
  end

  def remove_ips_for(spec)
    remove_results = {}

    spec.networks.each do |name|
      remove_results[name] = @networks[name.to_sym].remove_ip_for(spec)
    end

    return remove_results
  end

end
