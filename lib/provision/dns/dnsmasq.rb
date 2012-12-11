require "yaml"
class Provision::DNS::DNSMasq < Provision::DNS
  @@files_dir = "/etc"

  def self.files_dir=(f)
    @@files_dir = f
  end

  def initialize()
    super
    @hosts_file = "#{@@files_dir}/hosts"
    @ethers_file = "#{@@files_dir}/ethers"
    parse_hosts
  end

  def allocate_ip_for(spec)
    hn = spec[:fqdn]
    if @by_name[hn]
      puts "No new allocation for #{hn}, already allocated to #{@by_name[hn]}"
      @by_name[hn]
    else
      # FIXME - THERE IS NO CHECKING HERE - THIS WILL ALLOCATE THE BROADCAST ADDRESS...
      @max_ip = IPAddr.new(@max_ip.to_i + 1, Socket::AF_INET)
      puts "Allocated IP #{@max_ip} to host #{hn}"
      File.open(@hosts_file, 'a') { |f| f.write "#{@max_ip.to_s} #{hn}\n" }
      File.open(@ethers_file, 'a') { |f| f.write "#{spec.interfaces[0][:mac]} #{@max_ip.to_s}\n" }
      @by_name[hn] = @max_ip
      @max_ip
    end
  end

  def parse_hosts
    require 'ipaddr'
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

