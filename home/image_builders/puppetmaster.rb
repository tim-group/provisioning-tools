define "puppetmaster" do
  ubuntuprecise
  mcollective
  mcollective_server

  run("puppet mastery"){
    cmd "echo 'building puppetmaster' #{spec[:hostname]}"
    apt_install "rubygems"
    apt_install "puppetmaster"
    apt_install "rubygem-hiera"
    apt_install "rubygem-hiera-puppet"
    apt_install "puppetdb-terminus"
    # FIXME Need to throw the symlink in /usr/share/mcollective
    apt_install "puppet-updator"
  }

  cleanup {
    chroot "/etc/init.d/puppetmaster stop"
  }

  run("puppet master code checkout") {
    apt_install "git-core"
    chroot "rm -rf /etc/puppet"
    chroot "git clone http://git.youdevise.com/git/puppet /etc/puppet"
  }

  run("configure puppetmaster") {
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
    storeconfigs                   = true
    storeconfigs_backend           = puppetdb

[agent]
    report            = true

[masterbranch]
    modulepath=$confdir/modules
    manifest=$confdir/manifests/site.pp
"""
    }
  }

  run("add autosign") {
    open("#{spec[:temp_dir]}/etc/puppet/autosign.conf", 'w') { |f|
      f.puts """*.dev.net.local
"""
    }
  }

  run("configuring puppetdb terminus") {
    open("#{spec[:temp_dir]}/etc/puppet/puppetdb.conf", 'w') { |f|
      f.puts """[main]
server = #{spec[:fqdn]}
port   = 8081
"""
    }
  }

  run("nasty hack to install puppetdb with correct cert name") {
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts """#!/bin/sh -e
apt-get install -y --force-yes puppetdb
update-rc.d puppetdb defaults
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
exit 0
"""
    }
  }
end
