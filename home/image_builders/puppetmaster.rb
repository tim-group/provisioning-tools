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
    apt_install "libapache2-mod-passenger"
  }

  cleanup {
    chroot "/etc/init.d/puppetmaster stop"
    chroot "/etc/init.d/apache2 stop"
  }

  run("puppet master code checkout") {
    apt_install "git-core"
    chroot "rm -rf /etc/puppet"
    chroot "git clone http://git.youdevise.com/git/puppet /etc/puppet"
    chroot "chown -R puppet:puppet /etc/puppet"
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
    reports                        = foreman,successful_run_commit_id

[agent]
    report            = true

[masterbranch]
    modulepath=$confdir/modules
    manifest=$confdir/manifests/site.pp
"""
    }
  }

  run("configure apache for puppetmaster") {
    cmd "cp #{Dir.pwd}/files/apache2-puppetmaster #{spec[:temp_dir]}/etc/init.d/"
    cmd "cp #{Dir.pwd}/files/apache2-puppetmaster.conf #{spec[:temp_dir]}/etc/apache2/puppetmaster.conf"
    cmd "cp #{Dir.pwd}/files/puppetmaster #{spec[:temp_dir]}/etc/default/"
    chroot "update-rc.d apache2-puppetmaster defaults"
    chroot "update-rc.d -f apache2 remove"
  }

  run("add autosign") {
    open("#{spec[:temp_dir]}/etc/puppet/autosign.conf", 'w') { |f|
      f.puts """*.dev.net.local
*.stag.net.local
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
DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install puppetdb
sed -i 's/-Xmx192m/-Xmx512m/' /etc/default/puppetdb
update-rc.d puppetdb defaults
puppet cert clean --all
puppet cert generate #{spec[:fqdn]}
/etc/init.d/puppetdb restart
/etc/init.d/apache2-puppetmaster restart
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
exit 0
"""
    }
  }
end
