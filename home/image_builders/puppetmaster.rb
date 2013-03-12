define 'puppetmaster' do
  copyboot

  run('install puppet') {
    apt_install 'puppet'
  }

  run('clone puppet') {
    cmd "rm -rf #{spec[:temp_dir]}/etc/puppet"
    cmd "git clone http://git.youdevise.com/git/puppet #{spec[:temp_dir]}/etc/puppet"
    # FIXME Remove this once the code has been merged
    cmd "cd #{spec[:temp_dir]}/etc/puppet && git checkout puppetmaster_apply"
  }

  run('deploy puppetmaster') {
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts '#!/bin/sh -e
/usr/bin/puppet apply --pluginsync --modulepath=/etc/puppet/modules --logdest=syslog /etc/puppet/modules/puppetmaster/site.pp'
    }
  }
end
