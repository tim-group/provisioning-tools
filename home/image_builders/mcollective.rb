define "mcollective" do

  run("install and configure mcollective") {
    apt_install "ruby-stomp"
    apt_install "mcollective"
    cmd "cp #{Dir.pwd}/files/mcollective/server.cfg #{spec[:temp_dir]}/etc/mcollective/"

  }

  cleanup {
    chroot "/etc/init.d/mcollective stop"
  }


end
