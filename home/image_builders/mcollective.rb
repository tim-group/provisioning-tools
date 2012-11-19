define "mcollective" do
  ubuntuprecise

  run("mcollective") {
    cmd "cp -r #{Dir.pwd}/seed/mcollective  #{spec[:temp_dir]}/seed"
    apt_install "puppet"

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts """#!/bin/sh -e
 puppet apply /seed/install.pp -l /seed/init.log
 echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
 exit 0
      """
    }
  }

end
