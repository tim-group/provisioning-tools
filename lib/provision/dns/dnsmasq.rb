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

    def initialize(subnet_string, start_ip, options)
      @hosts_file = options[:hosts_file] || "/etc/hosts"
      @ethers_file = options[:ethers_file] || "/etc/ethers"
      @dnsmasq_pid_file = options[:pid_file] || "/var/run/dnsmasq.pid"
      @subnet = IPAddr.new(subnet_string)
      @subnet.extend(IPAddrExtensions)
      @start_ip = IPAddr.new(start_ip)
      parse_hosts
    end

    def allocate_ip_for(hostname, all_hostnames, network, mac)
      ip = nil
      # Note that we re-parse the hosts file on every allocation
      # to avoid multiple simultaneous allocators from being able
      # to allocate the same IP
      # FIXME - There is still a race condition here with other processes
      parse_hosts

      # <bodge degree="hideous">
      unless all_hostnames.include?(hostname)
        all_hostnames = [hostname] + all_hostnames
      end

      if @by_name[hostname]
        puts "No new allocation for #{hostname}, already allocated to #{@by_name[hostname]}"
        ip = @by_name[hostname]
        return {
          :address => ip.to_s,
          :netmask => @subnet.subnet_mask
        }
      else
        # FIXME - THERE IS NO CHECKING HERE - THIS WILL ALLOCATE THE BROADCAST ADDRESS...

        @max_ip = IPAddr.new(@max_ip.to_i + 1, Socket::AF_INET)
        puts "Allocated IP #{@max_ip} to host #{hostname}"
        File.open(@hosts_file, 'a') { |f|
          f.write "#{@max_ip.to_s} #{all_hostnames.join(" ")}\n"
          f.chmod(0644)
        }
        File.open(@ethers_file, 'a') { |f|
          f.write "#{mac} #{@max_ip.to_s}\n"
          f.chmod(0644)
        }

        reload_dnsmasq

        return {
          :address=>@max_ip.to_s,
          :netmask=>@subnet.subnet_mask}
      end
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
    def reload_dnsmasq
      if (File.exists?(@dnsmasq_pid_file))
        pid = File.open(@dnsmasq_pid_file).first.to_i
        puts "Reloading dnsmasq (#{pid})"
        Process.kill("HUP", pid)
      end
    end
  end

  def initialize(options={})
    super
    @options = options
    @hosts_file = options[:hosts_file] || "/etc/hosts"
    @ethers_file = options[:ethers_file] || "/etc/ethers"
    @dnsmasq_pid_file = options[:pid_file] || "/var/run/dnsmasq.pid"
  end

  def add_network(name, net, start)
    @networks[name] = Network.new(net,
                                  start,
                                  @options)
  end

end
