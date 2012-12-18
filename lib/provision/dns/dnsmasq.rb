require 'ipaddr'

class Provision::DNS::DNSMasq < Provision::DNS
  @@files_dir = ""

  def self.files_dir=(f)
    @@files_dir = f
  end

  def initialize()
    super
    @hosts_file = "#{@@files_dir}/etc/hosts"
    @ethers_file = "#{@@files_dir}/etc/ethers"
    @dnsmasq_pid_file = "#{@@files_dir}/var/run/dnsmasq.pid"
    parse_hosts
  end

  def reload_dnsmasq
    if (File.exists?(@dnsmasq_pid_file))
      pid = File.open(@dnsmasq_pid_file).first.to_i
      puts "Reloading dnsmasq (#{pid})"
      Process.kill("HUP", pid)
    end
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
    else
      # FIXME - THERE IS NO CHECKING HERE - THIS WILL ALLOCATE THE BROADCAST ADDRESS...

      @max_ip = IPAddr.new(@max_ip.to_i + 1, Socket::AF_INET)
      puts "Allocated IP #{@max_ip} to host #{spec.all_hostnames.join(" ")}"
      File.open(@hosts_file, 'a') { |f| f.write "#{@max_ip.to_s} #{spec.all_hostnames.join(" ")}\n" }
      File.open(@ethers_file, 'a') { |f|
        f.write "#{spec.interfaces[0][:mac]} #{@max_ip.to_s}\n"
      }
      reload_dnsmasq
      @max_ip
    end
  end

  private

  def parse_hosts
    network = IPAddr.new("192.168.5.0/24")
    @by_name = {}
    @max_ip = IPAddr.new("192.168.5.1")

    File.open(@hosts_file).each { |l|
      next if l =~ /^#/
      next if l =~ /^\s*$/
      next unless l =~ /^\d+\.\d+\.\d+\.\d+/
      splits = l.split("\s")
      ip = splits[0]
      names = splits[1..-1]
      next unless network.include?(ip)
      if IPAddr.new(ip) > @max_ip
        @max_ip = IPAddr.new(ip)
      end
      names.each { |n|
         @by_name[n] = ip
      }
    }
  end
end

