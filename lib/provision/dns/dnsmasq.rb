require 'ipaddr'
require 'fileutils'
require 'tempfile'
require 'thread'

$etc_hosts_mutex = Mutex.new
$etc_dnsmasqd_mutex = Mutex.new

class Provision::DNS::DNSMasq < Provision::DNS
end

class Provision::DNS::DNSMasqNetwork < Provision::DNSNetwork
  attr_reader :by_name
  attr_reader :by_cname

  def initialize(name, range, options={})
    if !options[:primary_nameserver]
      options[:primary_nameserver] = '127.0.0.1'
    end
    super(name, range, options)
    @hosts_file = options[:hosts_file] || "/etc/hosts"
    @cnames_file = options[:cnames_file] || "/etc/dnsmasq.d/cnames"
    @dnsmasq_pid_file = options[:pid_file] || "/var/run/dnsmasq.pid"
    parse_hosts
    parse_cnames
  end

  def lookup_ip_for(fqdn)
    @by_name[fqdn]
  end

  def lookup_cname_for(fqdn)
    @cnames_by_fqdn[fqdn]
  end

  # This does nothing in this class
  def add_forward_lookup(ip, hostname)
  end

  def try_add_reverse_lookup(ip, hostname, all_hostnames)
    $etc_hosts_mutex.synchronize do
      parse_hosts
      return false if @by_ip[ip.to_s]
      File.open(@hosts_file, 'a') { |f|
        f.write "#{ip.to_s} #{all_hostnames.join(" ")}\n"
        f.chmod(0644)
      }
      reload_dnsmasq
      return true
    end
  end

  def add_cname_lookup(fqdn, cname_fqdn)
    $etc_hosts_mutex.synchronize do
      parse_cnames
      cname_by_fqdn = @cnames_by_fqdn[fqdn]
      if cnames_by_fqd
        return false if cname_by_fqdn != cname_fqdn
      else
        File.open(@cnames_file, 'a') { |f|
          f.write "cname=#{fqdn},#{cname_fqdn}\n"
          f.chmod(0644)
        }
        reload_dnsmasq
      end
      return true
    end
  end

  def parse_hosts
    @by_name = {}
    @by_ip = {}
    File.open(@hosts_file).each { |l|
      next if l =~ /^#/
      next if l =~ /^\s*$/
      next unless l =~ /^\d+\.\d+\.\d+\.\d+/
      splits = l.split("\s")
      ip = splits[0]
      names = splits[1..-1]
      next unless @subnet.include?(ip)
      names.each { |n|
        @by_name[n] = ip
        @by_ip[ip] = n
      }
    }
  end

  def parse_cnames
    @cnames_by_fqdn = {}
    File.open(@cnames_file).each { |l|
      next unless l =~ /^cname=/
      splits = l.gsub(/^cname=/, '').split(',')
      raise("Bad cname entry in #{@cnames_file}, it contains a cname with #{splits.length} entries instead of 2") if splits.length != 2
      @cnames_by_fqdn[splits[0]] = splits[1]
    }
  end

  # This does nothing in this class
  def remove_forward_lookup(fqdn)
  end

  def remove_reverse_lookup(ip)
    parse_hosts
    hosts_removed = remove_lines_from_file(/^#{ip}.+$/, @hosts_file)
    hosts_removed > 0 ? reload_dnsmasq : false
  end

  def reload_dnsmasq
    if (File.exists?(@dnsmasq_pid_file))
      pid = File.open(@dnsmasq_pid_file).first.to_i
      puts "Reloading dnsmasq (#{pid})"
      Process.kill("HUP", pid)
    end
  end

  def remove_lines_from_file(regex,file)
    found = 0
    tmp_file = Tempfile.new('remove_temp')
    File.open(file, 'r') do |f|
      f.each_line{|line|
        matching_line = line =~ regex
        matching_line ? (found+=1) : (tmp_file.puts line)
      }
    end
    tmp_file.close
    File.new(tmp_file.path, 'a').chmod(0644)
    found > 0 ? FileUtils.mv(tmp_file.path, file) : false
    puts "#{found} lines removed from #{file}"
    return found
  end

  def reload_dnsmasq
    if (File.exists?(@dnsmasq_pid_file))
      pid = File.open(@dnsmasq_pid_file).first.to_i
      puts "Reloading dnsmasq (#{pid})"
      Process.kill("HUP", pid)
    end
  end
end
