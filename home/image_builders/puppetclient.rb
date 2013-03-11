define "puppetclient" do
  copyboot

  run("install puppet") {
    apt_install "puppet"
    open("#{spec[:temp_dir]}/etc/puppet/puppet.conf", 'w') { |f|
      f.puts "[main]
  vardir                         = /var/lib/puppet
  logdir                         = /var/log/puppet
  rundir                         = /var/run/puppet
  ssldir                         = $vardir/ssl
  factpath                       = $vardir/lib/facter
  templatedir                    = $confdir/templates
  pluginsync                     = true
  environment                    = masterbranch
  configtimeout                  = 3000
"
    }
  }

  run("seedapply") {
    cmd "mkdir #{spec[:temp_dir]}/seed"

    open("#{spec[:temp_dir]}/seed/puppet.sh", 'w') { |f|
      f.puts """#!/bin/sh -e
puppet agent --waitforcert 10 --onetime 2>&1 | tee /seed/init.log
      """
    }

    cmd "chmod 700 #{spec[:temp_dir]}/seed/puppet.sh"

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts """#!/bin/sh -e
echo 'Run ntpdate'
/usr/sbin/ntpdate -s ntp1
echo 'Running seed puppet'
/seed/puppet.sh
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
echo 'Finished running seed puppet'
exit 0
      """
    }
  }
end
