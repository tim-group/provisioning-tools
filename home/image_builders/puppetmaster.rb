define 'puppetmaster' do
  copyboot

  run('install puppet') {
    apt_install 'puppet'
  }

  run('clone puppet') {
    cmd "rm -rf #{spec[:temp_dir]}/etc/puppet"
    cmd "git clone http://git.youdevise.com/git/puppet #{spec[:temp_dir]}/etc/puppet"
  }

  run('install ruby') {
    apt_install 'ruby1.8'
    apt_install 'rubygems'
    apt_install 'rubygems1.8'
    apt_install 'rubygem-rspec'
  }
  run('deploy puppetmaster') {
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|

      f.puts "#!/bin/bash
echo 'Run ntpdate' | logger
/etc/init.d/ntp stop | logger 2>&1
/usr/sbin/ntpdate -s dc-1.net.local | logger 2>&1
/etc/init.d/ntp start | logger 2>&1
echo 'Run puppet apply' | logger
/usr/bin/puppet apply --pluginsync --modulepath=/etc/puppet/modules --logdest=syslog /etc/puppet/manifests/site.pp
/etc/init.d/apache2-puppetmaster restart 2>&1 | logger
puppet agent --debug --waitforcert 10 --onetime 2>&1 | tee /seed/init.log
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local"
    }
  }

end

