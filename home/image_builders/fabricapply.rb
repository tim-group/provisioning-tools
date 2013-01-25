define "fabricapply" do
  copyboot

  run("run apt-update ") {
    chroot "apt-get -y --force-yes update"
  }
  run("git clone puppet") {
    cmd "rm -Rf #{spec[:temp_dir]}/etc/puppet/*"
    cmd "git clone http://git.youdevise.com/git/puppet #{spec[:temp_dir]}/etc/puppet"
  }
  run("temporary route to existing fabric") {
    open("#{spec[:temp_dir]}//etc/network/if-up.d/routes_mgmt", "w") {|f|
      f.puts """
if [ "${IFACE}" == "mgmt" ]; then
ip route add 10.108.0.0/16 via 172.19.0.3
fi
"""
    }
    open("#{spec[:temp_dir]}/etc/hosts", 'a') { |f|
      f.puts "10.108.11.237 aptproxy deb\n"
    }
  }
  run("fabricapply") {
    cmd "mkdir #{spec[:temp_dir]}/seed"
    cmd "cp -r #{File.dirname(__FILE__)}/seed  #{spec[:temp_dir]}/"

    open("#{spec[:temp_dir]}/seed/puppet.yaml", "w") {|f|
      f.puts YAML.dump(spec[:enc])
    }

    open("#{spec[:temp_dir]}/seed/puppet.sh", 'w') { |f|
      f.puts """#!/bin/sh -e
puppet apply -v --pluginsync --modulepath=/etc/puppet/modules /etc/puppet/manifests/site.pp 2>&1 | tee /seed/init.log
      """
    }

    cmd "chmod 700 #{spec[:temp_dir]}/seed/puppet.sh"

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts """#!/bin/sh -e
echo 'Running seed puppet'
/seed/puppet.sh
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
echo 'Finished running fabric puppet'
exit 0
      """
    }
  }
end

