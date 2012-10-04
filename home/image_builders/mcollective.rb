define "mcollective" do

  run("install and configure mcollective") {
    apt_install "ruby-stomp"
    apt_install "mcollective"
    cmd "cp #{Dir.pwd}/files/mcollective/server.cfg #{spec[:temp_dir]}/etc/mcollective/"
  }

  run("install puppetd agent") {
    cmd "cp #{Dir.pwd}/files/mcollective/agents/puppetd.rb #{spec[:temp_dir]}/usr/share/mcollective/plugins/mcollective/agent/puppetd.rb"
    cmd "cp #{Dir.pwd}/files/mcollective/agents/puppetd.ddl #{spec[:temp_dir]}/usr/share/mcollective/plugins/mcollective/agent/puppetd.ddl"
  }

  cleanup {
    chroot "/etc/init.d/mcollective stop"
  }


end
