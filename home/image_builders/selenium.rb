define "selenium" do
  ubuntuprecise
  run("install selenium packages") {
    apt_install "google-chrome-stable"
    apt_install "selenium"
    apt_install "selenium-node"
    chroot "update-rc.d selenium-node defaults"
    chroot "sed -i'.bak' -e 's#^securerandom.source=file:/dev/urandom#securerandom.source=file:/dev/../dev/urandom#g' /etc/java-6-openjdk/security/java.security"
  }

  run("place the selenium node config") {
    hubparts = sehub.split(":")
    host = hubparts[0]
    port = hubparts[1]

    cmd "mkdir -p #{spec[:temp_dir]}/etc/default"
    open("#{spec[:temp_dir]}/etc/default/selenium", 'w') { |f|
      f.puts "HUBHOST=#{host}"
      f.puts "HUBPORT=#{port}"
    }
  }

end
