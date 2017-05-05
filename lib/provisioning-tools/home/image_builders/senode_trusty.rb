define "senode_trusty" do
  copyboot

  run("run apt-update ") do
    chroot "apt-get -y --force-yes update"
  end

  run("mounting devices") do
    cmd "mount --bind /dev #{spec[:temp_dir]}/dev"
    cmd "mount -t proc none #{spec[:temp_dir]}/proc"
    cmd "mount -t sysfs none #{spec[:temp_dir]}/sys"
  end

  cleanup do
    log.debug("cleaning up procs")
    log.debug(`mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp)
    keep_doing do
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/proc"
    end.until { `mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp == "0" }

    keep_doing do
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/sys"
    end.until { `mount -l | grep #{spec[:hostname]}/sys | wc -l`.chomp == "0" }

    keep_doing do
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/dev"
    end.until { `mount -l | grep #{spec[:hostname]}/dev | wc -l`.chomp == "0" }
  end

  run("create ci user") do
    chroot "/usr/sbin/adduser ci"
  end

  run("install selenium packages") do
    apt_install "zulu-8"
    chroot "sed -i'.bak' -e 's#^securerandom.source=.*#securerandom.source=file:/dev/./urandom#' \
      /usr/lib/jvm/zulu-8-amd64/jre/lib/security/java.security"

    apt_install "acpid"
    apt_install "xvfb"
    apt_install "dbus"
    apt_install "dbus-x11"
    apt_install "hicolor-icon-theme"

#    firefox_version = spec[:firefox_version] || "11.0+build1-0ubuntu4"
#    apt_install "firefox=#{firefox_version}"
#    chroot "ln -s /usr/lib/firefox/firefox /usr/bin/firefox-bin"

#    chrome_version = spec[:chrome_version] || "22.0.1229.79-r158531"
#    apt_install "google-chrome-stable=#{chrome_version}"

    selenium_version = spec[:selenium_version] || "2.32.0"
    apt_install "selenium=#{selenium_version}"

    apt_install "selenium-node"
    chroot "update-rc.d selenium-node defaults"
  end

  cleanup do
    chroot "/etc/init.d/dbus stop"
  end

  run("place the selenium node config") do
    host = spec[:selenium_hub_host]
    port = "7799"

    cmd "mkdir -p #{spec[:temp_dir]}/etc/default"
    open("#{spec[:temp_dir]}/etc/default/selenium-node", 'w') do |f|
      f.puts "HUBHOST=#{host}"
      f.puts "HUBPORT=#{port}"
    end
  end
end
