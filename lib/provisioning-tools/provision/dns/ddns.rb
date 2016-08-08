require 'ipaddr'
require 'rubygems'
require 'tempfile'
require 'provisioning-tools/provision/dns'
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
  def initialize(name, range, options = {})
    options[:primary_nameserver] = '127.0.0.1' if !options[:primary_nameserver]
    @reverse_zone_override = options[:reverse_zone_override]
    super(name, range, options)
    @debug = false
    parts = range.split('/')
    fail(":network_range must be of the format X.X.X.X/Y") if parts.size != 2
    @rndc_key = options[:rndc_key] || fail("No :rndc_key supplied")
    @resolver = options[:resolver] || Resolv::DNS.new(
      :nameserver => @primary_nameserver,
      :search => [],
      :ndots => 1
    )
  end

  def lookup_ip_for(fqdn)
    addresses = @resolver.getaddresses(fqdn)
    @resolver.getaddress(fqdn) if addresses.empty?

    addresses.collect do |address|
      IPAddr.new(address.to_s, Socket::AF_INET)
    end

  rescue Resolv::ResolvError
    puts "Could not find #{fqdn}"
    false
  end

  def lookup_cname_for(fqdn)
    cname = @resolver.getresource(fqdn, Resolv::DNS::Resource::IN::CNAME)
    return cname.name.to_s if cname
  rescue Resolv::ResolvError
    puts "Could not find cname for #{fqdn}"
    return nil
  end

  def reverse_zone
    if @reverse_zone_override
      "#{@reverse_zone_override.split('.').reverse.join('.')}.in-addr.arpa"
    else
      parts = @network.to_s.split('.').reverse
      smparts = @subnet_mask.to_s.split('.').reverse
      while smparts[0].to_i < 255
        smparts.shift
        parts.shift
      end
      "#{parts.join('.')}.in-addr.arpa"
    end
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

  def try_add_reverse_lookup(ip, fqdn, _all_hostnames)
    ip_rev = ip.to_s.split('.').reverse.join('.')
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{@primary_nameserver}"
    tmp_file.puts "zone #{reverse_zone}"
    tmp_file.puts "prereq nxdomain #{ip_rev}.in-addr.arpa"
    tmp_file.puts "update add #{ip_rev}.in-addr.arpa. 86400 PTR #{fqdn}."
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Add reverse from #{ip} to #{fqdn}")
  end

  def exec_nsupdate(update_file)
    rndc_tmp = write_rndc_key
    out = `cat #{update_file.path} | nsupdate -v -t 12 -k #{rndc_tmp.path} 2>&1`
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
      return false
    when /update failed: NOTAUTH\(BADKEY\)/
      fail(Provision::DNS::DDNS::Exception::BadKey.new(failure))
    when /Communication with server failed: timed out/
      fail(Provision::DNS::DDNS::Exception::Timeout.new(failure))
    when /^$/
      puts "SUCCESS: #{txt}"
      return true
    else
      fail(Provision::DNS::DDNS::Exception::UnknownError.new(failure))
    end
  end

  def get_hostname(fqdn)
    fqdn_s = fqdn.split "."
    zone_s = fqdn_s.clone
    hn = zone_s.shift
    hn
  end

  def get_zone(fqdn)
    fqdn_s = fqdn.split "."
    zone_s = fqdn_s.clone
    hn = zone_s.shift
    zone = zone_s.join('.')
    zone
  end

  def add_forward_lookup(ip, fqdn)
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{@primary_nameserver}"
    tmp_file.puts "zone #{get_zone(fqdn)}"
    tmp_file.puts "update add #{fqdn}. 86400 A #{ip}"
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Add forward from #{fqdn} to #{ip}")
  end

  def add_cname_lookup(fqdn, cname_fqdn)
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{@primary_nameserver}"
    tmp_file.puts "zone #{get_zone(fqdn)}"
    tmp_file.puts "update add #{fqdn}. 86400 CNAME #{cname_fqdn}"
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Add CNAME entry #{fqdn} -> #{cname_fqdn}")
  end

  def remove_forward_lookup(fqdn)
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{@primary_nameserver}"
    tmp_file.puts "zone #{get_zone(fqdn)}"
    tmp_file.puts "update delete #{fqdn}. A"
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Remove forward from #{fqdn}")
  end

  def remove_cname_lookup(fqdn, cname_fqdn)
    tmp_file = Tempfile.new('remove_temp')
    tmp_file.puts "server #{@primary_nameserver}"
    tmp_file.puts "zone #{get_zone(fqdn)}"
    tmp_file.puts "update delete #{fqdn}. CNAME"
    tmp_file.puts "send"
    tmp_file.close
    nsupdate(tmp_file, "Remove CNAME entry #{fqdn} -> #{cname_fqdn}")
  end

  def remove_reverse_lookup(ips)
    ips.each do |ip|
      ip_rev = ip.to_s.split('.').reverse.join('.')
      tmp_file = Tempfile.new('remove_temp')
      tmp_file.puts "server #{@primary_nameserver}"
      tmp_file.puts "zone #{reverse_zone}"
      tmp_file.puts "update delete #{ip_rev}.in-addr.arpa. PTR"
      tmp_file.puts "send"
      tmp_file.close
      nsupdate(tmp_file, "Remove reverse for #{ip}")
    end
  end
end
