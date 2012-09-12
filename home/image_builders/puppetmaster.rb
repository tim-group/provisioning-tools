
define "puppetmaster" do
  ubuntuprecise
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
    ###??
  }

  cleanup {
    chroot "/etc/init.d/puppetmaster stop"
  }

  run("puppet master code checkout") {
    # trash the modules, manifests, templates
    chroot "rmdir /etc/puppet/modules"
    chroot "rmdir /etc/puppet/manifests"
    chroot "rmdir /etc/puppet/templates"
#    cmd "cp -r /home/dellis/workspace/puppetx/* #{spec[:temp_dir]}/etc/puppet/"
  }

  run("write bootstrap puppet.conf") {

    # git clone puppet.git
#    git clone git@git:puppet /etc/puppet

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
