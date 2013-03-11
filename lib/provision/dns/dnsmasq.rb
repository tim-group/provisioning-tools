require 'ipaddr'
require 'fileutils'
require 'tempfile'

class Provision::DNS::DNSMasq < Provision::DNS
end

class Provision::DNS::DNSMasqNetwork < Provision::DNSNetwork
  attr_reader :max_ip
  attr_reader :by_name

  def initialize(name, range, options={})
    super(name, range, options)
    @hosts_file = options[:hosts_file] || "/etc/hosts"
    @ethers_file = options[:ethers_file] || "/etc/ethers"
    @dnsmasq_pid_file = options[:pid_file] || "/var/run/dnsmasq.pid"
    parse_hosts
  end

  def lookup_ip_for(hostname)
  end

  def try_add_reverse_lookup(ip, hostname)
  end

  # This does nothing in this class
  def add_forward_lookup(ip, hostname)
  end

  def allocate_ip_for(spec)
    ret = super(spec)

    interface = spec.interfaces.find do |interface|
      interface[:network].to_sym == @name
    end
    mac = interface[:mac]
    File.open(@ethers_file, 'a') do |f|
      f.write "#{mac} #{ret[:address]}\n"
      f.chmod(0644)
    end

    reload_dnsmasq

    return ret
  end

  def parse_hosts
    @by_name = {}
    @max_ip = @start_ip

    File.open(@hosts_file).each { |l|
      next if l =~ /^#/
        next if l =~ /^\s*$/
        next unless l =~ /^\d+\.\d+\.\d+\.\d+/
        splits = l.split("\s")
      ip = splits[0]
      names = splits[1..-1]
      next unless @subnet.include?(ip)
      if IPAddr.new(ip) > @max_ip
        @max_ip = IPAddr.new(ip)
      end
      names.each { |n|
        @by_name[n] = ip
      }
    }
  end

  def remove_ip_for(spec)
    ip = nil
    parse_hosts

    hn = spec.hostname_on(@name)
    if @by_name[hn]
      ip = @by_name[hn]
      puts "Removing ip allocation (#{ip}) for #{hn}"
      hosts_removed = remove_lines_from_file(/^#{ip}.+$/,@hosts_file)
      ethers_removed = remove_lines_from_file(/^.+#{ip}$/,@ethers_file)
        hosts_removed > 0 || ethers_removed > 0 ?  reload_dnsmasq : false
      return true
    else
      puts "No ip allocation found for #{hn}, not removing"
      return false
    end
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
