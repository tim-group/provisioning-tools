define "puppetclient" do
  copyboot

  run("install puppet") do
    apt_install "puppet"
    open("#{spec[:temp_dir]}/etc/puppet/puppet.conf", 'w') do |f|
      f.puts "[main]\n" \
        "  vardir                         = /var/lib/puppet\n" \
        "  logdir                         = /var/log/puppet\n" \
        "  rundir                         = /var/run/puppet\n" \
        "  ssldir                         = $vardir/ssl\n" \
        "  factpath                       = $vardir/lib/facter\n" \
        "  templatedir                    = $confdir/templates\n" \
        "  pluginsync                     = true\n" \
        "  environment                    = masterbranch\n" \
        "  configtimeout                  = 3000\n"
    end
  end

  run('setup one time password') do
    require 'rubygems'
    require 'rotp'

    totp = ROTP::TOTP.new(config[:otp_secret], :interval => 120)
    onetime = totp.now
    open("#{spec[:temp_dir]}/etc/puppet/csr_attributes.yaml", 'w') do |f|
      f.puts "extension_requests:\n" \
        "  pp_preshared_key: #{onetime}\n"
    end
  end

  run('install rc.local') do
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') do |f|
      f.puts "#!/bin/sh -e\n" \
        "echo 'Running rc.local'\n" \
        "echo 'Run ntpdate'\n" \
        "(/usr/sbin/ntpdate -b -v -d -s ci-1.youdevise.com 2>&1 | tee -a /tmp/bootstrap.log || exit 0)\n" \
        "echo 'Regenerating SSH hostkeys'\n" \
        "/bin/rm /etc/ssh/ssh_host_*\n" \
        "/usr/sbin/dpkg-reconfigure openssh-server\n" \
        "echo 'Running puppet agent'\n" \
        "puppet agent --debug --verbose --waitforcert 10 --onetime 2>&1 | tee -a /tmp/bootstrap.log\n" \
        "echo \"#!/bin/sh -e\\nexit 0\" > /etc/rc.local\n" \
        "echo 'Finished running rc.local'\n" \
        "exit 0\n"
    end
  end
end
