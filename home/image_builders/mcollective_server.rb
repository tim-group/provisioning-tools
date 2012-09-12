
define "mcollective_server" do

  run("install and configure activemq #{Dir.pwd}") {
    apt_install "activemq"

    chroot "ln -s /opt/activemq/bin/activemq /etc/init.d/activemq"
    cmd "cp #{Dir.pwd}/files/activemq.xml #{spec[:temp_dir]}/opt/activemq/conf/"
    chroot "update-rc.d activemq defaults"
  }	

end
