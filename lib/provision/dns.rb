class Provision::DNS
  def self.get_backend(name)
    require "provision/dns/#{name.downcase}"
    classname = "Provision::DNS::#{name}"
    classname.new()
  end
end

