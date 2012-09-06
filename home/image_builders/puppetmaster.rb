
define "puppetmaster" do
  ubuntuprecise

  run("puppet mastery"){
    cmd "echo 'building puppetmaster' #{spec[:hostname]}"
    apt_install "rubygems"
    apt_install "puppetmaster"
#    apt_install "libapache2-mod-passenger"
    apt_install "rubygem-hiera"
    apt_install "rubygem-hiera-puppet"
    apt_install "puppetdb"
    apt_install "puppetdb-terminus"
    ###??
  }


  run("puppet master code checkout") {
    # trash the modules, manifests, templates
    chroot "rmdir /etc/puppet/modules"
    chroot "rmdir /etc/puppet/manifests"
    cmd "cp -r /home/workspace/puppetx #{temp_dir}/etc/puppet/"
  }

  run("write bootstrap puppet.conf") {

    # git clone puppet.git
#    git clone git@git:puppet /etc/puppet

    open("#{spec[:temp_dir]}/etc/puppet/puppet.conf", 'w') { |f|
      f.puts 
%[

]
    }
  }

end
