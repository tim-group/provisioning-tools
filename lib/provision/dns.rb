require 'ipaddr'
require 'provision/namespace'
require 'logger'
require 'yaml'
require 'set'

module IPAddrExtensions
  def subnet_mask
    _to_string(@mask_addr)
  end
end

class Provision::DNSChecker
  attr_reader :logger
  def initialize(options)
    @logger = options[:logger] || Logger.new(STDERR)
    @primary_nameserver = options[:primary_nameserver] || '192.168.5.1'
  end

  def resolve(record, element, max_attempts = 10)
    attempt = 1
    addrinfo = Set.new
    while (attempt <= max_attempts)
      msg = "Lookup #{record} (#{attempt}/#{max_attempts})"
      begin
        addrinfo = Set.new(Socket.getaddrinfo(record, nil)).map { |a| a[element] }
        break
      rescue Exception => e
        logger.error("DNS RESOLVE FAILURE: #{msg} - #{e.inspect}")
        sleep 1
      end
      attempt += 1
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
    @primary_nameserver = options[:primary_nameserver] || raise("must specify a primary_nameserver")
    @checker = options[:checker] || Provision::DNSChecker.new(:logger => @logger,
                                                              :primary_nameserver => @primary_nameserver)
    parts = range.split('/')
    raise(":network_range must be of the format X.X.X.X/Y") if parts.size != 2
    broadcast_mask = (IPAddr::IN4MASK >> parts[1].to_i)
    @subnet_mask = IPAddr.new(IPAddr::IN4MASK ^ broadcast_mask, Socket::AF_INET)
    @network = IPAddr.new(parts[0]).mask(parts[1])
    @broadcast = @network | IPAddr.new(broadcast_mask, Socket::AF_INET)

    min_allocation = options[:min_allocation] || @network.to_i + 10
    @min_allocation = IPAddr.new(min_allocation, Socket::AF_INET)

    max_allocation = options[:max_allocation] || @broadcast.to_i - 1
    @max_allocation = IPAddr.new(max_allocation, Socket::AF_INET)
  end

  def hostname_from_spec(spec)
    spec.hostname_on(@name)
  end

  def allocate_ip_for(spec)
    hostname = hostname_from_spec spec
    all_hostnames = spec.all_hostnames_on(@name)
    ip = nil

    ip = lookup_ip_for(hostname)
    if ip
      @logger.info("No new allocation for #{hostname}, already allocated to #{ip}")
      puts "No new allocation for #{hostname}, already allocated"
      return {
        :netmask => @subnet_mask.to_s,
        :address => lookup_ip_for(hostname)
      }
    else
      max_ip = @max_allocation
      ip = @min_allocation
      @logger.info("Trying to allocate ips #{hostname} between #{ip} and #{max_ip}")

      while !try_add_reverse_lookup(ip, hostname, all_hostnames)
        ip = IPAddr.new(ip.to_i + 1, Socket::AF_INET)
        if ip >= max_ip
          raise("Ran out of IP Addresses for #{hostname} - Maximum IP reached: #{max_ip} - Minimum #{@min_allocation}")
        end
      end
      add_forward_lookup(ip, hostname)
    end

    raise "unable to resolve forward #{hostname} -> #{ip}" unless @checker.resolve_forward(hostname).include?(ip.to_s)
    raise "unable to resolve reverse #{ip} -> #{hostname}" unless @checker.resolve_reverse(ip.to_s).include?(hostname)

    {
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

    {
      :netmask => @subnet_mask.to_s,
      :address => ip
    }
  end

  def add_cnames_for(spec)
    unwrapped_spec = spec.spec
    cnames = unwrapped_spec[:cnames]

    result = {}
    cnames.each do |network_name, records|
      records.each do |hostname, cname|
        fqdn = "#{hostname}.#{spec.domain_on(network_name)}"
        existing_cname = lookup_cname_for(fqdn)
        if existing_cname
          if existing_cname == cname
            result.merge!(fqdn => cname)
            next
          else
            # Should we be unallocating here if it's already allocated?
            raise("fqdn: #{fqdn} is already a cname for: #{existing_cname}")
          end
        else
          add_cname_lookup(fqdn, cname)
        end
        result.merge!(fqdn => cname)

        raise "unable to resolve cname #{fqdn} -> #{cname}" unless @checker.resolve_forward(fqdn)
      end
    end
    result
  end

  def remove_cnames_for(spec)
    unwrapped_spec = spec.spec
    cnames = unwrapped_spec[:cnames]

    result = {}
    cnames.each do |network_name, records|
      records.each do |hostname, cname_fqdn|
        fqdn = "#{hostname}.#{spec.domain_on(network_name)}"
        existing_cname = lookup_cname_for(fqdn)
        if existing_cname
          if existing_cname == cname_fqdn
            remove_cname_lookup(fqdn, cname_fqdn)
            result.merge!(fqdn => cname_fqdn)
          else
            raise "#{fqdn} resolves to CNAME: '#{existing_cname}', not CNAME: '#{cname_fqdn}' that was expected, " \
              "not removing"
          end
        end
      end
    end
    result
  end
end

class Provision::DNS
  attr_accessor :backend

  def self.get_backend(name, options = {})
    raise("get_backend not supplied a name, cannot continue.") if name.nil? || name == false
    require "provision/dns/#{name.downcase}"
    instance = Provision::DNS.const_get(name).new(options)
    instance.backend = name
    instance
  end

  def initialize(options = {})
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

    start_time = Time.now

    # Should the rest of this allocation loop be folded into the machine spec?
    spec.networks.each do |network_name|
      network = network_name.to_sym

      @logger.info("Trying to allocate IPs for #{spec[:hostname]} in network #{network}")

      unless @networks.key?(network)
        @logger.info("Skipping IP allocation for #{spec[:hostname]} in network #{network}: no such network on " \
          "this node")
        next
      end

      allocations[network] = @networks[network].allocate_ip_for(spec)

      @logger.info("Allocated #{allocations[network][:address]} in network #{network_name} for node #{spec[:hostname]}")
    end

    raise("No networks allocated for this machine, cannot be sane") if allocations.empty?

    elapsed_time = (Time.now - start_time).to_f
    @logger.info(sprintf("IP allocation for #{spec[:hostname]} took %.6f seconds", elapsed_time))

    allocations
  end

  def remove_ips_for(spec)
    remove_results = {}

    spec.networks.each do |name|
      if !@networks.key?(name.to_sym)
        @logger.warn "can't remove an ip on #{name} because there is no config on the compute node. Known networks " \
          "#{@networks.keys.inspect}"
        next
      end

      remove_results[name] = @networks[name.to_sym].remove_ip_for(spec)
    end

    remove_results
  end

  def add_cnames_for(spec)
    raise("No networks for this machine, cannot add any CNAME's") if spec.networks.empty?
    result = {}
    return result if spec[:cnames].nil?
    spec.networks.each do |network_name|
      network = network_name.to_sym
      @logger.info("Trying to add CNAME's for network #{network}")
      next unless @networks.key?(network)
      next unless spec[:cnames].key?(network)
      result.merge!(@networks[network].add_cnames_for(spec))
    end
    result.each { |cname, destination| @logger.info("Added CNAME #{cname} -> #{destination}") }
    result
  end

  def remove_cnames_for(spec)
    raise("No networks for this machine, cannot remove any CNAME's") if spec.networks.empty?
    result = {}
    return result if spec[:cnames].nil?
    spec.networks.each do |network_name|
      network = network_name.to_sym
      @logger.info("Trying to remove CNAME's for network #{network}")
      next unless @networks.key?(network)
      next unless spec[:cnames].key?(network)
      result.merge!(@networks[network].remove_cnames_for(spec))
    end
    @logger.info("Removed #{result}")
    result
  end
end
