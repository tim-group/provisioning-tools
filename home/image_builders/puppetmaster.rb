define 'puppetmaster' do
  copyboot

  run('install puppet') {
    apt_install 'puppet'
  }

  run('clone puppet') {
    cmd "rm -rf #{spec[:temp_dir]}/etc/puppet"
    cmd "git clone http://git.youdevise.com/git/puppet #{spec[:temp_dir]}/etc/puppet"
    cmd "cp #{spec[:temp_dir]}/etc/puppet/modules/puppetmaster/files/hiera.yaml #{spec[:temp_dir]}/etc/puppet/hiera.yaml"
    cmd "cp #{spec[:temp_dir]}/etc/puppet/modules/puppetmaster/files/auth.conf #{spec[:temp_dir]}/etc/puppet/auth.conf"
    cmd "cp #{spec[:temp_dir]}/etc/puppet/modules/puppetmaster/files/routes.yaml #{spec[:temp_dir]}/etc/puppet/routes.yaml"
  }

  run('install ruby') {
    apt_install 'ruby1.8'
    apt_install 'rubygems'
    apt_install 'rubygems1.8'
    apt_install 'rubygem-rspec'
  }

  run('deploy puppetmaster') {
    # the puppetmaster needs the masterbranch to can bootstrap
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts "#!/bin/bash\n" \
             "\n" \
             "echo 'Run ntpdate' | logger\n" \
             "/etc/init.d/ntp stop | logger 2>&1\n" \
             "/usr/sbin/ntpdate -s ci-1.youdevise.com | logger 2>&1\n" \
             "/etc/init.d/ntp start | logger 2>&1\n" \
             "echo 'Clone the masterbranch puppet branch' | logger\n" \
             "git clone --mirror git://git/puppet.git /etc/puppet/puppet.git\n" \
             "mkdir -p /etc/puppet/environments\n" \
             "mkdir -p /etc/puppet/environments/masterbranch\n" \
             "git clone http://git.youdevise.com/git/puppet /etc/puppet/environments/masterbranch\n" \
             "echo 'Run puppet apply' | logger\n" \
             "puppet apply --debug --verbose --pluginsync --modulepath=/etc/puppet/modules --logdest=syslog /etc/puppet/manifests\n" \
             "/etc/init.d/apache2-puppetmaster restart 2>&1 | logger\n" \
             "puppet agent --debug --verbose --waitforcert 10 --onetime 2>&1 | logger\n" \
             "sleep 1 ; puppet cert sign $(hostname -f) 2>&1 | logger\n" \
             "echo \"#!/bin/sh -e\n\nexit 0\" > /etc/rc.local\n"
    }
  }
end
