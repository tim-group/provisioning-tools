define "seedapply" do
#  ubuntuprecise
  copyboot

  run("run apt-update ") {
    chroot "apt-get -y --force-yes update"
  }

  run("seedapply") {
    #pp spec[:enc]
    cmd "mkdir #{spec[:temp_dir]}/seed"
    cmd "cp -r #{File.dirname(__FILE__)}/seed  #{spec[:temp_dir]}/"
#    apt_install "puppet"


    if spec[:enc]["classes"].has_key?("puppetmaster") != nil
      cmd "cp -r #{File.dirname(__FILE__)}/ssl  #{spec[:temp_dir]}/var/lib/puppet/"
    else
      cmd "mkdir -p #{spec[:temp_dir]}/var/lib/puppet/ssl/private_keys"
      cmd "mkdir -p #{spec[:temp_dir]}/var/lib/puppet/ssl/certs"
      cmd "cp #{File.dirname(__FILE__)}/ssl/private_keys/generic.dev.net.local.pem  #{spec[:temp_dir]}/var/lib/puppet/ssl/private_keys/"
      cmd "cp #{File.dirname(__FILE__)}/ssl/ca/signed/generic.dev.net.local.pem  #{spec[:temp_dir]}/var/lib/puppet/ssl/certs/"
    end

    chroot "chown -R puppet /var/lib/puppet/ssl"

    open("#{spec[:temp_dir]}/seed/puppet.yaml", "w") {|f|
      f.puts YAML.dump(spec[:enc])
    }

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts """#!/bin/sh -e
echo 'Running seed puppet: '
cat /etc/resolv.conf > /seed/pre_puppet_resolv.conf
puppet apply /seed/manifests/seed.pp --node_terminus exec --external_nodes /seed/enc.sh --modulepath=/seed/modules 2>&1 | tee /seed/init.log
echo 'Finished running seed puppet.'
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
exit 0
      """
    }
  }

end
