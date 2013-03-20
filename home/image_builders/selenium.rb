define "selenium" do
  ubuntuprecise

  run("create ci user") {
    chroot "/usr/sbin/useradd ci -M"
  }

  run("install selenium packages") {
    apt_install "openjdk-6-jdk"
    apt_install "acpid"
    apt_install "xvfb"
    apt_install "firefox"
    apt_install "google-chrome-stable"
    apt_install "selenium"
    apt_install "selenium-node"
    chroot "update-rc.d selenium-node defaults"
    chroot "sed -i'.bak' -e 's#^securerandom.source=file:/dev/urandom#securerandom.source=file:/dev/../dev/urandom#g' /etc/java-6-openjdk/security/java.security"
  }

  run("configure google apt repo") {
    open("#{spec[:temp_dir]}/etc/apt/sources.list.d/google.list", 'w') { |f|
      f.puts "deb http://dl.google.com/linux/deb/ stable main\n"
    }

    chroot "curl -Ss https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -"
    suppress_error.chroot "apt-get update"
  }

  run("place the selenium node config") {
    hubparts = spec[:sehub].split(":")
    host = hubparts[0]
    port = hubparts[1]

    cmd "mkdir -p #{spec[:temp_dir]}/etc/default"
    open("#{spec[:temp_dir]}/etc/default/selenium-node", 'w') { |f|
      f.puts "HUBHOST=#{host}"
      f.puts "HUBPORT=#{port}"
    }
  }

end
