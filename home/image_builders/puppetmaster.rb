define 'puppetmaster' do
  copyboot

  run('install puppet') {
    apt_install 'puppet'
  }

  run('clone puppet') {
    cmd "rm -rf #{spec[:temp_dir]}/etc/puppet"
    cmd "git clone http://git.youdevise.com/git/puppet #{spec[:temp_dir]}/etc/puppet"
  }

  run('deploy puppetmaster') {
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts "#!/bin/sh -e
/usr/bin/puppet apply --pluginsync --modulepath=/etc/puppet/modules --logdest=syslog /etc/puppet/manifests/site.pp
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local"
    }
  }
end
