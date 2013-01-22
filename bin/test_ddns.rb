require 'provision/dns/ddns'

ddns = Provision::DNS.get_backend('DDNS', {
    :rndc_key => '6KBvyA/FS8CyaXCxfhPRzg=='
})
#ddns.add_network(name, net, start)
ddns.add_network('mgmt', '172.16.16.0/24', '172.16.16.10')
ddns.add_network('prod', '10.3.0.0/16', '10.3.0.10')

class MySpec
  def initialize(spec)
    @spec = spec
  end
  def [](name)
    @spec[name]
  end
  def hostname_on(network)
    if network == 'prod'
      "#{@spec[:hostname]}.#{@spec[:domain]}"
    else
      "#{@spec[:hostname]}.#{network}.#{@spec[:domain]}"
    end
  end
end

spec = MySpec.new(
  :hostname => 'test',
  :domain => 'st.net.local',
  :networks => ['mgmt', 'prod']
)

ddns.allocate_ips_for(spec)

