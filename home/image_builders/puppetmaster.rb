
define "puppetmaster" do
  ubuntuprecise
  mcollective
  mcollective_server

  run("puppet mastery"){
    cmd "echo 'building puppetmaster' #{spec[:hostname]}"
    apt_install "rubygems"
    apt_install "puppetmaster"
#    apt_install "libapache2-mod-passenger"
    apt_install "rubygem-hiera"
    apt_install "rubygem-hiera-puppet"
    apt_install "puppetdb"
    apt_install "puppetdb-terminus"
    apt_install "git-core"
    ###??
  }

  cleanup {
    chroot "/etc/init.d/puppetmaster stop"
  }

  run("puppet master code checkout") {
    chroot "rm -rf /etc/puppet"
    chroot "git clone http://git.youdevise.com/git/puppet /etc/puppet"
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
    server                         = #{spec[:fqdn]}

[master]
    certname                       = #{spec[:fqdn]}

[agent]
    report            = true

[masterbranch]
    modulepath=$confdir/modules/common
    manifest=$confdir/manifests/production/site.pp
"""}

  }

end
