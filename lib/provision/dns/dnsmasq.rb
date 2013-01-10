require 'ipaddr'
require 'fileutils'
require 'tempfile'

class Provision::DNS::DNSMasq < Provision::DNS
  @@files_dir = ""
  module IPAddrExtensions
    def subnet_mask
      return _to_string(@mask_addr)
    end
  end

  class Network
    attr_reader :max_ip
    attr_reader :by_name

    def initialize(subnet_string, options)
      @hosts_file = options[:hosts_file]
      @ethers_file = options[:ethers_file]
      @dnsmasq_pid_file = options[:dnsmasq_pid_file]
      @subnet = IPAddr.new(subnet_string)
      @subnet.extend(IPAddrExtensions)
      parse_hosts
    end

    def allocate_ip_for(spec)
      ip = nil
      # Note that we re-parse the hosts file on every allocation
      # to avoid multiple simultaneous allocators from being able
      # to allocate the same IP
      # FIXME - There is still a race condition here with other processes
      parse_hosts

      hn = spec[:fqdn]
      if @by_name[hn]
        puts "No new allocation for #{hn}, already allocated to #{@by_name[hn]}"
        ip = @by_name[hn]
        return {
          :address=>ip,
          :netmask=>@subnet.subnet_mask}
      else
        # FIXME - THERE IS NO CHECKING HERE - THIS WILL ALLOCATE THE BROADCAST ADDRESS...

        @max_ip = IPAddr.new(@max_ip.to_i + 1, Socket::AF_INET)
        puts "Allocated IP #{@max_ip} to host #{spec.all_hostnames.join(" ")}"
        File.open(@hosts_file, 'a') { |f|
          f.write "#{@max_ip.to_s} #{spec.all_hostnames.join(" ")}\n"
          f.chmod(0644)
        }
        File.open(@ethers_file, 'a') { |f|
          f.write "#{spec.interfaces[0][:mac]} #{@max_ip.to_s}\n"
          f.chmod(0644)
        }

        reload_dnsmasq

        return {
          :address=>@max_ip,
          :netmask=>@subnet.subnet_mask}
      end
    end

    def parse_hosts
      @by_name = {}
      @max_ip = @subnet.to_range.first.succ

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

      hn = spec[:fqdn]
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
  end

  def self.files_dir=(f)
    @@files_dir = f
  end

  def initialize()
    @hosts_file = "#{@@files_dir}/etc/hosts"
    @ethers_file = "#{@@files_dir}/etc/ethers"
    @dnsmasq_pid_file = "#{@@files_dir}/var/run/dnsmasq.pid"
    @networks = {}
  end

  def add_network(name, range)
    @networks[name] = Network.new(range,
                                  :hosts_file=>@hosts_file,
                                  :ethers_file=>@ethers_file,
                                  :dnsmasq_pid_file=>@dnsmasq_pid_file)
  end

  def reload_dnsmasq
    if (File.exists?(@dnsmasq_pid_file))
      pid = File.open(@dnsmasq_pid_file).first.to_i
      puts "Reloading dnsmasq (#{pid})"
      Process.kill("HUP", pid)
    end
  end

  def allocate_ips_for(spec)
    allocations = {}

    @networks.each do |name, net|
      allocations[name] = net.allocate_ip_for(spec)
    end

    return allocations
  end

  def remove_ips_for(spec)
    remove_results = {}

    @networks.each do |name, net|
      remove_results[name] = net.remove_ip_for(spec)
    end

    return remove_results
  end
end

