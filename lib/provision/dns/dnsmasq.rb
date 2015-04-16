require 'ipaddr'
require 'fileutils'
require 'tempfile'
require 'thread'

$etc_hosts_mutex = Mutex.new

class Provision::DNS::DNSMasq < Provision::DNS
end

class Provision::DNS::DNSMasqNetwork < Provision::DNSNetwork
  attr_reader :by_name
  attr_reader :by_cname

  def initialize(name, range, options = {})
    if !options[:primary_nameserver]
      options[:primary_nameserver] = '127.0.0.1'
    end
    super(name, range, options)
    @hosts_file = options[:hosts_file] || "/etc/hosts"
    @cnames_file = options[:cnames_file] || "/etc/dnsmasq.d/cnames"
    @dnsmasq_pid_file = options[:pid_file] || "/var/run/dnsmasq.pid"
    parse_hosts
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
      File.open(@hosts_file, 'a') do |f|
        f.write "#{ip} #{all_hostnames.join(' ')}\n"
        f.chmod(0644)
      end
      reload_dnsmasq
      return true
    end
  end

  def add_cname_lookup(fqdn, cname_fqdn)
    $etc_hosts_mutex.synchronize do
      parse_hosts
      return if @cnames_by_fqdn[fqdn] == cname_fqdn
      ip = @by_name[cname_fqdn]
      if ip
        temp_file = Tempfile.new('etc_hosts_update')
        begin
          File.open(@hosts_file, 'r') do |file|
            file.each_line do |line|
              if line =~ /^#{Regexp.escape(ip)}\s+/
                temp_file.puts line.strip + " #{fqdn}"
              else
                temp_file.puts line
              end
            end
          end
          temp_file.rewind
          FileUtils.mv(temp_file.path, @hosts_file)
          File.chmod(0644, @hosts_file)
          reload_dnsmasq
        ensure
          temp_file.close
          temp_file.unlink
        end
      else
        raise "Unable to add CNAME for '#{fqdn}' as CNAME: '#{cname_fqdn}' does not have an IP address associated with it"
      end
    end
  end

  def remove_cname_lookup(fqdn, cname_fqdn)
    $etc_hosts_mutex.synchronize do
      parse_hosts
      # return if @cnames_by_fqdn[fqdn] == cname_fqdn
      ip = @by_name[cname_fqdn]
      if ip
        temp_file = Tempfile.new('etc_hosts_update')
        begin
          File.open(@hosts_file, 'r') do |file|
            file.each_line do |line|
              if line =~ /^#{Regexp.escape(ip)}\s+/
                temp_file.puts line.gsub(/\s+#{Regexp.escape(fqdn)}/, '').strip
              else
                temp_file.puts line
              end
            end
          end
          temp_file.rewind
          FileUtils.mv(temp_file.path, @hosts_file)
          File.chmod(0644, @hosts_file)
          reload_dnsmasq
        ensure
          temp_file.close
          temp_file.unlink
        end
      else
        raise "Unable to add CNAME for '#{fqdn}' as CNAME: '#{cname_fqdn}' does not have an IP address associated with it"
      end
    end
  end

  def parse_hosts
    @by_name = {}
    @by_ip = {}
    @cnames_by_fqdn = {}
    File.open(@hosts_file).each do |l|
      next if l =~ /^#/
      next if l =~ /^\s*$/
      next unless l =~ /^\d+\.\d+\.\d+\.\d+/
      splits = l.split("\s")
      ip = splits[0]
      names = splits[1..-1]
      next unless @subnet.include?(ip)
      names.each_index do |i|
        name = names[i]
        @by_name[name] = ip
        @by_ip[ip] = name if i == 0
        @cnames_by_fqdn[name] = names[0] if i > 0
      end
    end
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
    if File.exists?(@dnsmasq_pid_file)
      pid = File.open(@dnsmasq_pid_file).first.to_i
      puts "Reloading dnsmasq (#{pid})"
      Process.kill('HUP', pid)
    end
  end

  def remove_lines_from_file(regex, file)
    found = 0
    tmp_file = Tempfile.new('remove_temp')
    File.open(file, 'r') do |f|
      f.each_line do|line|
        matching_line = line =~ regex
        matching_line ? (found += 1) : (tmp_file.puts line)
      end
    end
    tmp_file.close
    File.new(tmp_file.path, 'a').chmod(0644)
    found > 0 ? FileUtils.mv(tmp_file.path, file) : false
    puts "#{found} lines removed from #{file}"
    found
  end
end
