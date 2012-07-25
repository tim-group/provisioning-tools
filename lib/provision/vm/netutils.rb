require 'provision/vm/namespace'

module Provision::VM::NetUtils
  @@lease_file = "/opt/my.lease"

  def self.lease_file=(lease_file)
    @@lease_file = lease_file
  end

  def ip_address()
    print "#{mac_address}<<<<"
    cmd = "cat #{@@lease_file} | grep -i #{mac_address} | awk '{print $3}'"
    print cmd
    return `#{cmd}`.chomp
  end

  def mac_address()
    domain = @hostname
    raise 'kvm_mac(): Requires a string type ' +
      'to work with' unless domain.is_a?(String)

    raise 'kvm_mac(): An argument given cannot ' +
      'be an empty string value.' if domain.empty?

    # This is probably impossible as Digest is part of the Ruby Core ...
    begin
      require 'digest/sha1'
    rescue LoadError
      raise 'kvm_mac(): Unable to load Digest::SHA1 library.'
    end

    #
    # Generate SHA1 digest from given fully-qualified domain name and/or any
    # arbitrary string given ...
    #
    sha1  = Digest::SHA1.new
    bytes = sha1.digest(domain)

    #
    # We take only three hexadecimal values: one from the begging, one from
    # the middle of the digest and one from the end; which hopefully will
    # ensure uniqueness of the MAC address we have ...
    #
    "52:54:00:%s" % bytes.unpack('H2x9H2x8H2').join(':').tr('a-z', 'A-Z')
  end

end
