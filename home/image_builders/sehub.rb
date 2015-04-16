define "sehub" do
  copyboot

  run("run apt-update ") do
    chroot "apt-get -y --force-yes update"
  end

  run("create ci user") do
    chroot "/usr/sbin/useradd ci -M"
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

  run("install selenium packages") do
    apt_install "openjdk-7-jdk"
    selenium_version = spec[:selenium_version] || "2.32.0"
    apt_install "selenium=#{selenium_version}"
    apt_install "selenium-hub"
#    chroot "update-rc.d selenium-node defaults"
 #   chroot "sed -i'.bak' -e 's#^securerandom.source=file:/dev/urandom#securerandom.source=file:/dev/../dev/urandom#g' /etc/java-7-openjdk/security/java.security"
  end

  run("put in sehub monitoring stuff") do
    apt_install "python-lxml"
    open("#{spec[:temp_dir]}/etc/segrid.properties", 'w') do |f|
      f.puts """
[segrid]
segrid.filter=#{spec[:hostname]}
segrid.nodes=#{spec[:nodes].join(',')}
      """
    end
  end

  cleanup do
    chroot "/etc/init.d/selenium-hub stop"
  end
end
