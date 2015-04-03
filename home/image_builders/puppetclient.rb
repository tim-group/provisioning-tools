define "puppetclient" do
  copyboot

  run("install puppet") do
    apt_install "puppet"
    open("#{spec[:temp_dir]}/etc/puppet/puppet.conf", 'w') do |f|
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
    end
  end

  run("setup one time password") do
    require 'rubygems'
    require 'rotp'
    totp = ROTP::TOTP.new(config[:otp_secret], :interval => 120)
    onetime = totp.now
    open("#{spec[:temp_dir]}/etc/puppet/csr_attributes.yaml", 'w') do |f|
      f.puts """extension_requests:
  pp_preshared_key: #{onetime}
      """
    end
  end

  run("seedapply") do
    cmd "mkdir #{spec[:temp_dir]}/seed"

    open("#{spec[:temp_dir]}/seed/puppet.sh", 'w') do |f|
      f.puts """#!/bin/sh -e
puppet agent --debug --verbose --waitforcert 10 --onetime 2>&1 | tee /seed/init.log
      """
    end

    cmd "chmod 700 #{spec[:temp_dir]}/seed/puppet.sh"

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') do |f|
      f.puts """#!/bin/sh -e
echo 'Run ntpdate'
(/usr/sbin/ntpdate -b -v -d -s ci-1.youdevise.com > /tmp/ntpdate.log 2>&1 || exit 0)
echo 'Running seed puppet'
/seed/puppet.sh
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
echo 'Finished running seed puppet'
exit 0
      """
    end
  end
end
