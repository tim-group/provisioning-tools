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
/usr/sbin/ntpdate -s dc-1.net.local | logger 2>&1
echo 'Run puppet apply' | logger
/usr/bin/puppet apply --pluginsync --modulepath=/etc/puppet/modules --logdest=syslog /etc/puppet/manifests/site.pp
echo 'Sleep whilst puppetdb spins up' | logger 2>&1
sleep 30;
echo 'Run puppet agent first time to ask for cert' | logger
/usr/bin/puppet agent -t
echo 'Signing dev-puppetmaster-001.mgmt.dev.net.local cert' | logger
puppet cert sign dev-puppetmaster-001.mgmt.dev.net.local 2>&1 | logger
echo 'Running puppet agent against myself for real' | logger
/usr/bin/puppet agent -t

echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local"
    }
  }

end
