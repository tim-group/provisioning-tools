class Provision::DNS::Fake < Provision::DNS
  @@max_ip = IPAddr.new("192.168.5.1")
  def allocate_ips_for(spec)
      @@max_ip = IPAddr.new(@@max_ip.to_i + 1, Socket::AF_INET)
  end

  def remove_ips_for(spec)
    return true
  end
end
