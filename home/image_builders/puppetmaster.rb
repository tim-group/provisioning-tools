
define "puppetmaster" do
  ubuntuprecise

  run("puppet mastery"){
    cmd "echo 'building puppetmaster' #{spec[:hostname]}"
    apt_install "puppetmaster"
    #apt_install "libapache2-mod-passenger"
    apt_install "rubygem-hiera"
    apt_install "rubygem-hiera-puppet"
    apt_install "puppetdb"
    apt_install "puppetdb-terminus"
    ###??
  }
end
