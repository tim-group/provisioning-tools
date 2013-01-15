require 'ipaddr'
require 'rubygems'
require 'tempfile'
require 'provision/dns'
require 'resolv'

class Provision::DNS::DDNS < Provision::DNS
  class Network
    def initialize(options={})
      range = options[:network_range] || raise("No :network_range supplied")
      parts = range.split('/')
      if parts.size != 2
        raise(":network_range must be of the format X.X.X.X/Y")
      end
      broadcast_mask = (IPAddr::IN4MASK >> parts[1].to_i)
      @subnet_mask = IPAddr.new(IPAddr::IN4MASK ^ broadcast_mask, Socket::AF_INET)
      @network = IPAddr.new(parts[0]).mask(parts[1])
      @broadcast = @network | IPAddr.new(broadcast_mask, Socket::AF_INET)
      @max_allocation = IPAddr.new(@broadcast.to_i - 1, Socket::AF_INET)
      min_allocation = options[:min_allocation] || 10
      @min_allocation = IPAddr.new(min_allocation.to_i + @network.to_i, Socket::AF_INET)
      @rndc_key = options[:rndc_key] || raise("No :rndc_key supplied")
    end

    def reverse_zone
      parts = @network.to_s.split('.').reverse
      while parts[0] == "0"
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
      '172.16.16.5'
    end

    def remove_ip_for(spec)
      hn = spec[:fqdn]
      puts "Not ability to remove DNS for #{hn}, not removing"
      return false
    end

    def try_add_reverse_lookup(ip, fqdn)
      ip_rev = ip.to_s.split('.').reverse.join('.')
      tmp_file = Tempfile.new('remove_temp')
      tmp_file.puts "server #{get_primary_nameserver}"
      tmp_file.puts "zone #{reverse_zone}"
      tmp_file.puts "prereq nxdomain #{ip_rev}.in-addr.arpa"
      tmp_file.puts "update add #{ip_rev}.in-addr.arpa. 86400 PTR #{fqdn}."
      tmp_file.puts "send"
      tmp_file.close
      out = exec_nsupdate(tmp_file)
      if out =~ /update failed: YXDOMAIN/
        puts "FAILED TO ADD #{ip_rev}.in-addr.arpa. PTR #{fqdn}. IP already used"
        return false
      else
        if out =~ /update failed/
          raise("Adding lookup from #{ip} to #{fqdn} failed: #{out}")
        else
          puts "ADD OK for reverse of #{ip} to #{fqdn} => #{out}"
          return true
        end
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
      tmp_file.puts "server #{get_primary_nameserver}"
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
      begin
        IPAddr.new(Resolv.getaddress(hn))
      rescue Resolv::ResolvError
        puts "Could not find #{hn}"
        false
      end
    end

    def allocate_ip_for(spec)
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
      {
          :netmask => @subnet_mask.to_s,
          :address => ip
      }
    end
  end

  def initialize(options={})
    super
    @rndc_key = options["rndc_key"]
  end

  def add_network(name, net, start)
    @networks[name] = Network.new(
      :network_range => net,
      :rndc_key => @rndc_key
    )
  end
end

