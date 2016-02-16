define 'puppetserver' do
  copyboot

  run('install puppet') do
    apt_install 'puppet'
  end

  run('configure puppet') do
    open("#{spec[:temp_dir]}/etc/puppet/puppet.conf", 'w') do |f|
      f.puts \
        "[main]\n" \
        "  vardir        = /var/lib/puppet\n" \
        "  logdir        = /var/log/puppet\n" \
        "  rundir        = /var/run/puppet\n" \
        "  confdir       = /etc/puppet\n" \
        "  ssldir        = $vardir/ssl\n" \
        "  runinterval   = 600\n" \
        "  pluginsync    = true\n" \
        "  factpath      = $vardir/lib/facter\n" \
        "  splay         = false\n" \
        "  environment   = masterbranch\n" \
        "  configtimeout = 3000\n" \
        "  preferred_serialization_format = msgpack\n" \
        "  catalog_cache_terminus  = json\n" \
        "  strict_variables = true\n" \
        "  trusted_server_facts = true\n" \
        "  trusted_node_data = true\n" \
        "  parser = future\n" \
        "[agent]\n" \
        "  report            = true\n" \
        "[master]\n" \
        "  node_terminus  = stacks\n" \
        "  environmentpath = $confdir/environments\n" \
        "  reportdir         = $vardir/reports\n" \
      "  certname          = puppet.DOMAIN\n" \
      "  dns_alt_names     = puppet.DOMAIN,HOSTNAME,puppet"
    end
  end

  run('install rubygem-mongo') do
    apt_install 'rubygem-mongo'
  end

  run('deploy puppetserver') do
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') do |f|
      f.puts "#!/bin/bash\n" \
        "\n" \
        "test -e /etc/rc.local-puppetserver && sh /etc/rc.local-puppetserver\n" \
    end

    # * XXX symlink hieradata for the puppet apply run, a better way would be to specify hieradata path as an argument
    open("#{spec[:temp_dir]}/etc/rc.local-puppetserver", 'w') do |f|
      f.puts "#!/bin/bash\n" \
             "\n" \
             "echo 'running ntpdate...' | logger\n" \
             "/etc/init.d/ntp stop | logger 2>&1\n" \
             "/usr/sbin/ntpdate -s ci-1.youdevise.com | logger 2>&1\n" \
             "/etc/init.d/ntp start | logger 2>&1\n" \
             "\n" \
             "echo 'mirroring puppet.git...' | logger\n" \
             "git clone --mirror git://git.youdevise.com/puppet.git /etc/puppet/puppet.git\n" \
             "mkdir -p /etc/puppet/environments/masterbranch/\n" \
             "echo 'checking out the master branch...' | logger\n" \
             "git --git-dir=/etc/puppet/puppet.git --work-tree=/etc/puppet/environments/masterbranch/ checkout " \
               "--detach --force master\n" \
             "ln -s /etc/puppet/environments/masterbranch/modules/puppetmaster/files/hiera.yaml " \
               "/etc/puppet/hiera.yaml\n" \
             "ln -s /etc/puppet/environments/masterbranch/modules/puppetmaster/files/auth.conf " \
               "/etc/puppet/auth.conf\n" \
             "ln -s /etc/puppet/environments/masterbranch/hieradata/ /etc/puppet/hieradata # XXX needed " \
               "for puppet apply\n" \
             "sed -i -e \"s/HOSTNAME/\$(hostname -f)/g\" /etc/puppet/puppet.conf\n" \
             "sed -i -e \"s/DOMAIN/\$(hostname -d)/g\" /etc/puppet/puppet.conf\n" \
             "echo 'running puppet apply...' | logger\n" \
             "puppet apply --debug --verbose --pluginsync --modulepath=/etc/puppet/environments/masterbranch/modules " \
               "--logdest=syslog /etc/puppet/environments/masterbranch/manifests\n" \
             "\n" \
             "echo 'running puppet agent...' | logger\n" \
             "puppet agent --debug --verbose --waitforcert 10 --onetime 2>&1 | logger\n" \
             "sleep 10 ; puppet cert sign $(hostname -f) 2>&1 | logger\n" \
             "\n" \
             "echo 'all done' | logger\n" \
             "mv /etc/rc.local-puppetserver /etc/rc.local-puppetserver-done\n"
    end
  end
end
