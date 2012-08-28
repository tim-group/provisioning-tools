
define "puppetmaster" do
  run("puppet mastery"){
    cmd "echo 'building puppetmaster' #{spec[:hostname]}"
    apt_install puppetmaster
    ###??
  }
end
