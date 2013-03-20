require 'ipaddr'
require 'rubygems'
require 'tempfile'
require 'provision/dns'
require 'resolv'

class Provision::DNS::DDNS < Provision::DNS
end

module Provision::DNS::DDNS::Exception
    class BadKey < Exception
    end
    class Timeout < Exception
    end
    class UnknownError < Exception
    end
end

class Provision::DNS::DDNSNetwork < Provision::DNSNetwork
  def initialize(name, range, options={})
    if !options[:primary_nameserver]
      options[:primary_nameserver] = '127.0.0.1'
    end
    super(name, range, options)
    @debug = false
    parts = range.split('/')
    if parts.size != 2
      raise(":network_range must be of the format X.X.X.X/Y")
    end
    @rndc_key = options[:rndc_key] || raise("No :rndc_key supplied")
  end

  def get_primary_nameserver
    @primary_nameserver
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

  def reverse_zone
    parts = @network.to_s.split('.').reverse
    smparts = @subnet_mask.to_s.split('.').reverse
    while smparts[0].to_i < 255
      smparts.shift
      parts.shift
    end
    "#{parts.join('.')}.in-addr.arpa"
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

  def get_primary_nameserver
    return @primary_nameserver
  end

  def try_add_reverse_lookup(ip, fqdn, all_hostnames)
    ip_rev = ip.to_s.split('.').reverse.join('.')
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{get_primary_nameserver}"
    tmp_file.puts "zone #{reverse_zone}"
    tmp_file.puts "prereq nxdomain #{ip_rev}.in-addr.arpa"
    tmp_file.puts "update add #{ip_rev}.in-addr.arpa. 86400 PTR #{fqdn}."
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Add reverse from #{ip.to_s} to #{fqdn}")
  end

  def exec_nsupdate(update_file)
    rndc_tmp = write_rndc_key
    out = `cat #{update_file.path} | nsupdate -r 10 -u 1 -t 12 -k #{rndc_tmp.path} 2>&1`
    logger.info("nsupdate OUT #{out}") if @debug
    update_file.unlink
    rndc_tmp.unlink
    out
  end

  def nsupdate(update_file, txt)
    if @debug
      content = IO.read(update_file.path)
      logger.info("about to nsupdate for #{txt}: #{content}")
    end
    out = exec_nsupdate(update_file)
    check_nsupdate_output(out, txt)
  end

  def check_nsupdate_output(out, txt)
    failure = "#{txt} failed: '#{out}'"
    case out
    when /update failed: YXDOMAIN/
      puts "FAILED TO ADD #{txt} - IP already used"
      return false
    when /update failed: NOTAUTH\(BADKEY\)/
      raise(Provision::DNS::DDNS::Exception::BadKey.new(failure))
    when /Communication with server failed: timed out/
      raise(Provision::DNS::DDNS::Exception::Timeout.new(failure))
    when /^$/
      return true
    else
      raise(Provision::DNS::DDNS::Exception::UnknownError.new(failure))
    end
  end

  def get_hostname(fqdn)
    fqdn_s = fqdn.split "."
    zone_s = fqdn_s.clone
    hn = zone_s.shift
    return hn
  end

  def get_zone(fqdn)
    fqdn_s = fqdn.split "."
    zone_s = fqdn_s.clone
    hn = zone_s.shift
    zone = zone_s.join('.')
    return zone
  end

  def add_forward_lookup(ip, fqdn)
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{get_primary_nameserver}"
    tmp_file.puts "zone #{get_zone(fqdn)}"
    tmp_file.puts "update add #{fqdn}. 86400 A #{ip}"
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Add forward from #{fqdn} to #{ip}")
  end

  def remove_forward_lookup(fqdn)
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{get_primary_nameserver}"
    tmp_file.puts "zone #{get_zone(fqdn)}"
    tmp_file.puts "update delete #{fqdn}. A"
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Remove forward from #{fqdn}")
  end

  def remove_reverse_lookup(ip)
    ip_rev = ip.to_s.split('.').reverse.join('.')
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{get_primary_nameserver}"
    tmp_file.puts "zone #{reverse_zone}"
    tmp_file.puts "update delete #{ip_rev}.in-addr.arpa. PTR"
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Remove reverse for #{ip.to_s}")
  end
end

