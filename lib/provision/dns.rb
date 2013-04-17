require 'ipaddr'
require 'provision/namespace'
require 'logger'
require 'yaml'
require 'set'

module IPAddrExtensions
  def subnet_mask
    return _to_string(@mask_addr)
  end
end

class Provision::DNSChecker
 def initialize(options)
   @logger = options[:logger] || Logger.new(STDERR)
 end
 def resolve(record, element, max_attempts=10)
    attempt = 1
    addrinfo = []
    while (attempt <= max_attempts)
      begin
        msg = "Lookup #{record} (#{attempt}/#{max_attempts})"
        addrinfo = Set.new(Socket.getaddrinfo(record, nil)).map { |a| a[element] }
        break
      rescue Exception => e
       logger.error("DNS RESOLVE FAILURE: #{msg} - #{e.inspect}")
       sleep 1
      end
      attempt = attempt +1
    end
    attempt >= max_attempts ? (raise "Lookup #{record} failed after #{max_attempts} attempts") : false
    logger.info("SUCCESS: #{msg} resolved to #{addrinfo.join(' ')}")
    addrinfo
  end

  def resolve_forward(hostname)
     resolve(hostname, 3)
  end

  def resolve_reverse(ip)
    resolve(ip, 2)
  end

end

class Provision::DNSNetwork
  attr_reader :logger

  def initialize(name, range, options)
    @name = name
    @subnet = IPAddr.new(range)
    @subnet.extend(IPAddrExtensions)
    @logger = options[:logger] || Logger.new(STDERR)
    @checker = options[:checker] || Provision::DNSChecker.new(:logger => @logger)

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

    @primary_nameserver = options[:primary_nameserver] || raise("must specify a primary_nameserver")
  end

  def hostname_from_spec(spec)
     spec.hostname_on(@name)
  end

  def allocate_ip_for(spec)
     hostname = hostname_from_spec spec
     all_hostnames = spec.all_hostnames_on(@name)
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
       while !try_add_reverse_lookup(ip, hostname, all_hostnames)
         ip = IPAddr.new(ip.to_i + 1, Socket::AF_INET)
         if ip >= max_ip
           raise("Ran out of ips")
         end
       end
       add_forward_lookup(ip, hostname)
     end

     raise "unable to resolve forward #{hostname} -> #{ip.to_s}" unless @checker.resolve_forward(hostname).include?(ip.to_s)
     raise "unable to resolve reverse #{ip.to_s} -> #{hostname}" unless @checker.resolve_reverse(ip.to_s).include?(hostname)

     return {
       :netmask => @subnet_mask.to_s,
       :address => ip.to_s
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

      if not @networks.has_key?(name.to_sym)
        @logger.warn "can't allocate an address on #{name} because there is no config on the compute node. Known networks #{@networks.keys.inspect}"
        next
      end

      remove_results[name] = @networks[name.to_sym].remove_ip_for(spec)
    end

    return remove_results
  end

end
