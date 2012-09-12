
define "mcollective_server" do

  run("install and configure activemq #{Dir.pwd}") {
    apt_install "activemq"

    chroot "ln -s /opt/activemq/bin/activemq #{spec[:temp_dir]}/etc/init.d/activemq"
    cmd "cp #{Dir.pwd}/files/activemq.xml /opt/activemq/conf/"
  }	

end
