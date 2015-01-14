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
    cmd "mkdir #{spec[:temp_dir]}/seed"
    cmd "cp -r #{File.dirname(__FILE__)}/seed  #{spec[:temp_dir]}/"
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|

      f.puts "#!/bin/bash
echo 'Run ntpdate' | logger
/etc/init.d/ntp stop | logger 2>&1
/usr/sbin/ntpdate -s ci-1.youdevise.com | logger 2>&1
/etc/init.d/ntp start | logger 2>&1
echo 'Run puppet apply' | logger
/usr/bin/puppet apply --debug --verbose --pluginsync --modulepath=/etc/puppet/modules --logdest=syslog /etc/puppet/manifests/00_site.pp
/etc/init.d/apache2-puppetmaster restart 2>&1 | logger
puppet agent --debug --verbose --waitforcert 10 --onetime 2>&1 | tee /seed/init.log
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local"
    }
  }

end

