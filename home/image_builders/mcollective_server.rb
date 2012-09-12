
define "mcollective_server" do

  run("install and configure activemq") {
    apt_install "activemq"
    log.info("CWD #{Dir.pwd}")

    chroot "ln -s /opt/activemq/bin/activemq /etc/init.d/activemq"
    cmd "cp #{spec[:temp_dir]}/../../files/activemq.xml /opt/activemq/conf/"
  }	

end
