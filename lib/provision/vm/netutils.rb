require 'digest/sha1'
require 'provision/vm/namespace'

module Provision::VM::NetUtils
  @@lease_file = "/tmp/dhcp.leases"

  def self.lease_file=(lease_file)
    @@lease_file = lease_file
  end

  def interfaces()
    nics =[]
    slot = 6
    self.spec[:networks].each {|net|
      nics << {
		:slot=>slot,
		:mac=> mac_address("#{self.spec[:hostname]}.#{net}"),
		:bridge=> "br_#{net}",
    :network=>"#{net}"
	}
      slot = slot+1
    }
    nics
  end

  def mac_address(domain = self.spec[:hostname])
    raise 'kvm_mac(): Requires a string type ' +
      'to work with' unless domain.is_a?(String)
    raise 'kvm_mac(): An argument given cannot ' +
      'be an empty string value.' if domain.empty?
    sha1  = Digest::SHA1.new
    bytes = sha1.digest(domain)
    "52:54:00:%s" % bytes.unpack('H2x9H2x8H2').join(':')
  end

end

