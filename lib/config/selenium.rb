
define "selenium" do
  ubuntuprecise

  run("create ci user") {
    chroot "/usr/sbin/useradd ci"
  }

  run("install selenium packages") {
    apt_install "google-chrome-stable"
    apt_install "firefox"
    apt_install "selenium"
    apt_install "selenium-node"
    apt_install "openjdk-6-jre"
    apt_install "xvfb"
    chroot "update-rc.d selenium-node defaults"
    chroot "sed -i'.bak' -e 's#^securerandom.source=file:/dev/urandom#securerandom.source=file:/dev/../dev/urandom#g' /etc/java-6-openjdk/security/java.security"
  }
end
