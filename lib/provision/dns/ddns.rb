require 'ipaddr'
require 'rubygems'
require 'Dnsruby'
require 'provision/dns'

class Provision::DNS::DDNS < Provision::DNS
#  def initialize(options={})
#    super
#    @range = options[:range] || raise("No network range supplied")
#    @min_allocation = options[:min_allocation] || 10
#  end

  def get_primary_nameserver_for(zone)
    'moo'
  end

  def reverse_zone
    '16.16.172.in-addr.arpa'
  end

  def calc_max_ip_to_allocate
    '172.16.16.255'
  end

  def calc_min_ip_to_allocate
    '172.16.16.16'
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

  def remove_ip_for(spec)
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
    ip_rev = ip.split('.').reverse.join('.')
    update.absent("#{ip_rev}.in-addr.arpa.", 'PTR') # prereq
    update.add("#{ip_rev}.in-addr.arpa.", 'PTR', 86400, "#{fqdn}.")
    send_update(reverse_zone, update)
  end

  def allocate_ip_for(spec)
    ip = nil

    hn = spec[:fqdn]
    if lookup_ip_for(spec)
      puts "No new allocation for #{hn}, already allocated to #{@by_name[hn]}"
      return lookup_ip_for(spec)
    else

      max_ip = calc_max_ip_to_allocate
      ip = calc_min_ip_to_allocate
      while !try_add_reverse_lookup(ip, hn)
        ip = IPAddr.new(ip + 1, Socket::AF_INET)
      end
    end
    ip
  end
end

