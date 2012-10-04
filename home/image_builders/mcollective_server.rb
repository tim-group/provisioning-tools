define "mcollective_server" do

  run("install and configure activemq #{Dir.pwd}") {
    apt_install "activemq"

    chroot "ln -s /opt/activemq/bin/activemq /etc/init.d/activemq"
    cmd "cp #{Dir.pwd}/files/activemq.xml #{spec[:temp_dir]}/opt/activemq/conf/"
    chroot "update-rc.d activemq defaults"
  }

  run("install and configure mcollective client") {
    apt_install "mcollective-client"
    cmd "cp #{Dir.pwd}/files/mcollective/client.cfg #{spec[:temp_dir]}/etc/mcollective/"
  }

  run("install puppetd application") {
    cmd "cp #{Dir.pwd}/files/mcollective/applications/puppetd.rb #{spec[:temp_dir]}/usr/share/mcollective/plugins/mcollective/application/puppetd.rb"
  }

end
