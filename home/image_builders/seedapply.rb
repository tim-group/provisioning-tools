define "seedapply" do
  ubuntuprecise

  run("seedapply") {
    cmd "mkdir #{spec[:temp_dir]}/seed"
    cmd "cp -r #{File.dirname(__FILE__)}/seed  #{spec[:temp_dir]}/"
    apt_install "puppet"

    #    cmd "cp -r #{File.dirname(__FILE__)}/ssl  #{spec[:temp_dir]}/var/lib/puppet/"
    cmd "mkdir -p #{spec[:temp_dir]}/var/lib/puppet/ssl/private_keys"
    cmd "mkdir -p #{spec[:temp_dir]}/var/lib/puppet/ssl/certs"

    cmd "cp #{File.dirname(__FILE__)}/ssl/private_keys/generic.dev.net.local.pem  #{spec[:temp_dir]}/var/lib/puppet/ssl/private_keys/"
    cmd "cp #{File.dirname(__FILE__)}/ssl/ca/signed/generic.dev.net.local.pem  #{spec[:temp_dir]}/var/lib/puppet/ssl/certs/"

    chroot "chown -R puppet /var/lib/puppet/ssl"

    open("#{spec[:temp_dir]}/seed/puppet.yaml", "w") {|f|
      f.puts YAML.dump(spec[:enc])
    }

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts """#!/bin/sh -e
 puppet apply /seed/manifests/seed.pp --node_terminus exec --external_nodes /seed/enc.sh --modulepath=/seed/modules -l /seed/init.log
 echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
 exit 0
      """
    }
  }

end
