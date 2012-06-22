
define "selenium" do
  ubuntuprecise
  run("install selenium packages") {
    apt_install "google-chrome-stable"
    apt_install "selenium"
    apt_install "selenium-node"
    chroot "update-rc.d selenium-node defaults"
    chroot "sed -i'.bak' -e 's#^securerandom.source=file:/dev/urandom#securerandom.source=file:/dev/../dev/urandom#g' /etc/java-6-openjdk/security/java.security"
  }
end
