define 'puppetmaster' do
  copyboot

  run('install puppet') {
    apt_install 'puppet'
  }

  run('install ruby') {
    apt_install 'ruby1.8'
    apt_install 'rubygems'
    apt_install 'rubygems1.8'
    apt_install 'rubygem-rspec'
  }

  run('deploy puppetmaster') {
    # * sets up puppet.git and environments/masterbranch for puppetupdate
    # * runs puppet apply from the checked out masterbranch
    # * runs a proper puppet agent, signs the cert for itself
    # * XXX symlink hieradata for the puppet apply run, a better way would be to specify hieradata path as an argument
    # XXX dev-puppetmaster currently broken, clone into /etc/puppet for it to work
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts "#!/bin/bash\n" \
             "\n" \
             "echo 'running ntpdate...' | logger\n" \
             "/etc/init.d/ntp stop | logger 2>&1\n" \
             "/usr/sbin/ntpdate -s ci-1.youdevise.com | logger 2>&1\n" \
             "/etc/init.d/ntp start | logger 2>&1\n" \
             "\n" \
             "echo 'mirroring puppet.git...' | logger\n" \
             "git clone --mirror git://git.youdevise.com/puppet.git /etc/puppet/puppet.git\n" \
             "mkdir -p /etc/puppet/environments/masterbranch/\n" \
             "echo 'checking out the master branch...' | logger\n" \
             "git --git-dir=/etc/puppet/puppet.git --work-tree=/etc/puppet/environments/masterbranch/ checkout " \
               "--detach --force master\n" \
             "ln -s /etc/puppet/environments/masterbranch/modules/puppetmaster/files/hiera.yaml " \
               "/etc/puppet/hiera.yaml\n" \
             "ln -s /etc/puppet/environments/masterbranch/modules/puppetmaster/files/auth.conf " \
               "/etc/puppet/auth.conf\n" \
             "ln -s /etc/puppet/environments/masterbranch/modules/puppetmaster/files/routes.yaml " \
               "/etc/puppet/routes.yaml\n" \
             "ln -s /etc/puppet/environments/masterbranch/hieradata/ hieradata # XXX needed for puppet apply\n" \
             "\n" \
             "echo 'running puppet apply...' | logger\n" \
             "puppet apply --debug --verbose --pluginsync --modulepath=/etc/puppet/environments/masterbranch/modules" \
               "--logdest=syslog /etc/puppet/environments/masterbranch/manifests\n" \
             "rm /etc/puppet/hieradata # XXX no longer needed\n" \
             "/etc/init.d/apache2-puppetmaster restart 2>&1 | logger\n" \
             "\n" \
             "echo 'running puppet agent...' | logger\n" \
             "puppet agent --debug --verbose --waitforcert 10 --onetime 2>&1 | logger\n" \
             "sleep 10 ; puppet cert sign $(hostname -f) 2>&1 | logger\n" \
             "\n" \
             "echo 'all done' | logger\n" \
             "echo \"#!/bin/sh -e\n\nexit 0\" > /etc/rc.local\n"
    }
  }
end
