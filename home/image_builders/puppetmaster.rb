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

      f.puts "#!/bin/bash -e
echo 'Run ntpdate'
/usr/sbin/ntpdate -s dc-1.net.local
echo 'Run puppet apply'
/usr/bin/puppet apply --pluginsync --modulepath=/etc/puppet/modules --logdest=syslog /etc/puppet/manifests/site.pp

sleep 30

echo 'Run puppet again due to not loading facts and other stuff.. meh'
/usr/bin/puppet agent -t
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local"
    }
  }

end
