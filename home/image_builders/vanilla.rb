define "vanilla" do
  copyboot

  run("run apt-update ") {
    chroot "apt-get -y --force-yes update"
  }

  run("vanilla") {
    cmd "mkdir #{spec[:temp_dir]}/seed"
#    cmd "cp -r #{File.dirname(__FILE__)}/seed  #{spec[:temp_dir]}/"

    if spec[:enc]["classes"].has_key?("puppetmaster")
      cmd "cp -r #{File.dirname(__FILE__)}/ssl  #{spec[:temp_dir]}/var/lib/puppet/"
      chroot "chown -R puppet /var/lib/puppet/ssl"
    end

    open("#{spec[:temp_dir]}/seed/enc.sh", 'w') { |f|
      f.puts """#!/bin/sh -e
cat /seed/puppet.yaml
      """
    }

    cmd "chmod 700 #{spec[:temp_dir]}/seed/enc.sh"

    open("#{spec[:temp_dir]}/seed/puppet.yaml", "w") {|f|
      f.puts YAML.dump(spec[:enc])
    }

    open("#{spec[:temp_dir]}/seed/puppet.sh", 'w') { |f|
      f.puts """#!/bin/sh -e

mv /etc/puppet/puppet.conf /etc/puppet.conf.rescued
rm -rf /etc/puppet
git clone http://git/git/puppet /etc/puppet
mv /etc/puppet.conf.rescued /etc/puppet/puppet.conf
apt-get install rubygem-hiera rubygem-hiera-puppet
puppet apply /etc/puppet/manifests/site.pp --node_terminus exec --external_nodes /seed/enc.sh --modulepath=/etc/puppet/modules 2>&1 | tee /seed/init.log
      """
    }

    cmd "chmod 700 #{spec[:temp_dir]}/seed/puppet.sh"

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts """#!/bin/sh -e
echo 'Running seed puppet'
/seed/puppet.sh
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
echo 'Finished running seed puppet'
exit 0
      """
    }
  }
end

