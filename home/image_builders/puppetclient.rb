
define "puppetclient" do
  ubuntuprecise
  mcollective

  run("puppet client modules"){
    cmd "echo 'building puppetmaster' #{spec[:hostname]}"
    apt_install "rubygems"
    apt_install "rubygem-hiera"
    apt_install "rubygem-hiera-puppet"
    apt_install "puppet"
    apt_install "facter"
 }

  run("write bootstrap puppet.conf") {
    open("#{spec[:temp_dir]}/etc/puppet/puppet.conf", 'w') { |f|
      f.puts """
[main]
    vardir                         = /var/lib/puppet
    logdir                         = /var/log/puppet
    rundir                         = /var/run/puppet
    confdir                        = /etc/puppet
    ssldir                         = $vardir/ssl
    runinterval                    = 600
    pluginsync                     = true
    factpath                       = $vardir/lib/facter
    splay                          = false
    preferred_serialization_format = marshal
    environment                    = masterbranch
    configtimeout                  = 3000
    server                         = #{spec[:env]}-puppetmaster-001.#{spec[:domain]}

[master]
    certname                       = #{spec[:fqdn]}

[agent]
    report            = true

"""}

  }

end
