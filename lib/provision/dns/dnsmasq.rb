class Provision::DNS::DNSMasq < Provision::DNS
  def initialize()
    super
  end

  def allocate_ip_for(spec)
    "1.1.1.1"
  end

end

