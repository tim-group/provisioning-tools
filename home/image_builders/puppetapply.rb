define "puppetapply" do
  ubuntuprecise

  run("puppetapply") {
    cmd "mkdir #{spec[:temp_dir]}/seed"
    cmd "cp -r #{File.dirname(__FILE__)}/seed/#{spec[:seed]}/  #{spec[:temp_dir]}/seed"
    apt_install "puppet"

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts """#!/bin/sh -e
 puppet apply /seed/#{spec[:seed]}/install.pp --modulepath=/seed/#{spec[:seed]} -l /seed/init.log
 echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
 exit 0
      """
    }
  }

end
