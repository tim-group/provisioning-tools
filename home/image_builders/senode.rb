define "senode" do
  copyboot

  run("mounting devices") {
    cmd "mount --bind /dev #{spec[:temp_dir]}/dev"
    cmd "mount -t proc none #{spec[:temp_dir]}/proc"
    cmd "mount -t sysfs none #{spec[:temp_dir]}/sys"
  }

  cleanup {
    log.debug("cleaning up procs")
    log.debug(`mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp)
    keep_doing {
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/proc"
    }.until {`mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp == "0"}

    keep_doing {
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/sys"
    }.until {`mount -l | grep #{spec[:hostname]}/sys | wc -l`.chomp == "0"}

    keep_doing {
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/dev"
    }.until {`mount -l | grep #{spec[:hostname]}/dev | wc -l`.chomp == "0"}
  }

#run("configure google apt repo") {
#    open("#{spec[:temp_dir]}/etc/apt/sources.list.d/google.list", 'w') { |f|
#      f.puts "deb http://dl.google.com/linux/deb/ stable main\n"
#    }

#    chroot "curl -Ss https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -"
#    suppress_error.chroot "apt-get update"
#  }

  run("create ci user") {
    chroot "/usr/sbin/adduser ci"
  }

  run("install selenium packages") {
    apt_install "openjdk-6-jdk"
    apt_install "acpid"
    apt_install "xvfb"
    apt_install "dbus"
    apt_install "dbus-x11"
    apt_install "hicolor-icon-theme"
    apt_install "firefox"
    apt_install "google-chrome-stable"
    apt_install "selenium"
    apt_install "selenium-node"
    chroot "update-rc.d selenium-node defaults"
    chroot "sed -i'.bak' -e 's#^securerandom.source=file:/dev/urandom#securerandom.source=file:/dev/../dev/urandom#g' /etc/java-6-openjdk/security/java.security"
    chroot "ln -s /usr/lib/firefox/firefox /usr/bin/firefox-bin"
  }

  cleanup {
    chroot "/etc/init.d/dbus stop"
  }

  run("place the selenium node config") {
    host = spec[:se_hub]
    port = "7799"

    cmd "mkdir -p #{spec[:temp_dir]}/etc/default"
    open("#{spec[:temp_dir]}/etc/default/selenium-node", 'w') { |f|
      f.puts "HUBHOST=#{host}"
      f.puts "HUBPORT=#{port}"
    }
  }

end
