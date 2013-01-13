require 'ipaddr'
require 'rubygems'
require 'Dnsruby'
require 'provision/dns'

class Provision::DNS::DDNS < Provision::DNS
  def initialize(options={})
    super()
    range = options[:network_range] || raise("No :network_range supplied")
    parts = range.split('/')
    if parts.size != 2
      raise(":network_range must be of the format X.X.X.X/Y")
    end
    broadcast_mask = (IPAddr::IN4MASK >> parts[1].to_i)
    @network = IPAddr.new(parts[0]).mask(parts[1])
    @broadcast = @network | IPAddr.new(broadcast_mask, Socket::AF_INET)
    @max_allocation = IPAddr.new(@broadcast.to_i - 1, Socket::AF_INET)
    min_allocation = options[:min_allocation] || 10
    @min_allocation = IPAddr.new(min_allocation.to_i + @network.to_i, Socket::AF_INET)
  end

  def reverse_zone

    '16.16.172.in-addr.arpa'
  end

  def get_primary_nameserver_for(zone)
    '172.16.16.5'
  end

  def send_update(zone, update)
    res = Dnsruby::Resolver.new({:nameserver => get_primary_nameserver_for(zone)})
    ok = true
    begin
     reply = res.send_message(update)
     print "Update succeeded\n"
    rescue Exception => e
      print "Update failed: #{e}\n"
      ok = false
    end
    ok
  end

  def remove_ips_for(spec)
    ip = nil
    hn = spec[:fqdn]
    if @by_name[hn]
      ip = @by_name[hn]
      puts "Removing ip allocation (#{ip}) for #{hn}"
      return true
    else
      puts "No ip allocation found for #{hn}, not removing"
      return false
    end
  end

  def try_add_reverse_lookup(ip, fqdn)
    update = Dnsruby::Update.new(reverse_zone)
    ip_rev = ip.to_s.split('.').reverse.join('.')
    update.absent("#{ip_rev}.in-addr.arpa.", 'PTR') # prereq
    update.add("#{ip_rev}.in-addr.arpa.", 'PTR', 86400, "#{fqdn}.")
    send_update(reverse_zone, update)
  end

  def allocate_ips_for(spec)
    ip = nil

    hn = spec[:fqdn]
    if lookup_ip_for(spec)
      puts "No new allocation for #{hn}, already allocated to #{@by_name[hn]}"
      return lookup_ip_for(spec)
    else

      max_ip = @max_allocation
      ip = @min_allocation
      while !try_add_reverse_lookup(ip, hn)
        ip = IPAddr.new(ip.to_i + 1, Socket::AF_INET)
        if ip >= max_ip
            raise("Ran out of ips")
        end
      end
    end
    ip
  end
end

