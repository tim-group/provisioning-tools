require 'ipaddr'
require 'rubygems'
require 'Dnsruby'
require 'tempfile'
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
    @rndc_key = options[:rndc_key] || raise("No :rndc_key supplied")
  end

  def write_rndc_key
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "key \"rndc-key\" {"
    tmp_file.puts "algorithm hmac-md5;"
    tmp_file.puts "secret \"#{@rndc_key}\";"
    tmp_file.puts "};"
    tmp_file.close
    tmp_file
  end

  def get_primary_nameserver_for(zone)
#    '172.16.16.5'
    '127.0.0.1'
  end

  def remove_ips_for(spec)
    hn = spec[:fqdn]
    puts "Not ability to remove DNS for #{hn}, not removing"
    return false
  end

  def try_add_reverse_lookup(ip, fqdn)
    ip_rev = ip.to_s.split('.').reverse.join('.')
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server 127.0.0.1"
    tmp_file.puts "zone 16.16.172.in-addr.arpa"
    tmp_file.puts "prereq nxdomain #{ip_rev}.in-addr.arpa"
    tmp_file.puts "update add #{ip_rev}.in-addr.arpa. 86400 PTR #{fqdn}."
    tmp_file.puts "send"
    tmp_file.close
    out = exec_nsupdate(tmp_file)
    if out =~ /update failed: YXDOMAIN/
      puts "FAILED TO ADD #{ip_rev}.in-addr.arpa. PTR #{fqdn}. IP already used"
      return false
    else
      puts "ADD OK for reverse of #{ip} to #{fqdn} => #{out}"
      return true
    end
  end

  def exec_nsupdate(update_file)
    rndc_tmp = write_rndc_key
    out = `cat #{update_file.path} | nsupdate -k #{rndc_tmp.path} 2>&1`
    update_file.unlink
    rndc_tmp.unlink
    out
  end

  def add_forward_lookup(ip, fqdn)
    fqdn_s = fqdn.split "."
    zone_s = fqdn_s.clone
    hn = zone_s.shift
    zone = zone_s.join('.')
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server 127.0.0.1"
    tmp_file.puts "zone #{zone}"
    tmp_file.puts "update add #{fqdn}. 86400 A #{ip}"
    tmp_file.puts "send"
    tmp_file.close
    out = exec_nsupdate(tmp_file)
    if out =~ /^$/
      return true
    else
      raise("Could not add forward lookup #{fqdn} A #{ip}: #{out}")
    end
  end

  def lookup_ip_for(hn)
    res = Dnsruby::Resolver.new(:nameserver => "127.0.0.1")
    begin
      ret = res.query(hn) # Defaults to A record
      IPAddr.new(ret.answer.rrset(hn).rrs[0].data)
    rescue Dnsruby::NXDomain
      puts "Could not find #{hn}"
      return false
    rescue Dnsruby::ServFail
      puts "Could not find #{hn}"
      return false
    end
  end

  def allocate_ips_for(spec)
    ip = nil

    hn = spec[:fqdn]
    if lookup_ip_for(hn)
      puts "No new allocation for #{hn}, already allocated"
      return lookup_ip_for(hn)
    else

      max_ip = @max_allocation
      ip = @min_allocation
      while !try_add_reverse_lookup(ip, hn)
        ip = IPAddr.new(ip.to_i + 1, Socket::AF_INET)
        if ip >= max_ip
            raise("Ran out of ips")
        end
      end
      add_forward_lookup(ip, hn)
    end
    IPAddr.new(ip)
  end
end

