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
        "  pluginsync                     = true\n" \
        "  environment                    = masterbranch\n" \
        "  configtimeout                  = 3000\n" \
        "  preferred_serialization_format = msgpack\n" \
        "  use_srv_records                = true\n" \
        "  srv_domain                     = #{spec[:logicalenv]}.mgmt.#{spec[:domain]}\n" \
        "  # BUG Fixed in Puppet 4.0 (https://tickets.puppetlabs.com/browse/PUP-1035)\n" \
        "  pluginsource                   = puppet:///plugins\n" \
        "  pluginfactsource               = puppet:///pluginfacts\n"
    end
  end

  run('patch puppet because its crap') do
    open("/tmp/puppet.patch", 'w') do |f|
      f.puts "diff --git a/puppet/network/http/pool.rb b/puppet/network/http/pool.rb\n" \
       "index b817b47..25eae68 100644\n" \
       "--- a/puppet/network/http/pool.rb\n" \
       "+++ b/puppet/network/http/pool.rb\n" \
       "@@ -81,10 +81,19 @@ def borrow(site, verify)\n" \
       "\n" \
       '      Puppet.debug("Starting connection for \#{site}")' + "\n" \
       "      http.start\n" \
       "+      setsockopts(http.instance_variable_get(:@socket))\n" \
       "      http\n" \
       "    end\n" \
       "  end\n" \
       "\n" \
       "+  # Set useful socket option(s) which lack from default settings in Net:HTTP\n" \
       "+  #\n" \
       "+  # @api private\n" \
       "+  def setsockopts(netio)\n" \
       "+    socket = netio.io\n" \
       "+    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)\n" \
       "+  end\n" \
       "+\n" \
       "  # Release a connection back into the pool.\n" \
       "  #\n" \
       "  # @api private\n"
    end
  end

  run('patch the patch') do
    cmd "cd #{spec[:temp_dir]}/usr/lib/ruby/vendor_ruby/; patch -p 1 < /tmp/puppet.patch"
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
