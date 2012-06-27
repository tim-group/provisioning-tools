##### DREAMY ######
Provisioning RoadMap - Staging Environment and beyond
=====================================================

1. Ability to programatically provision a vanilla ubuntu box running the puppetmaster as a first example.

i.e. something like this:
    %provision --name dellis-puppetmaster --template puppetmaster

2. Ability to programmatically provision a machine that autoruns puppet without human intervention.

3. Ability to provision a kvm hosts worth of machines,
  i.e given something like this:
    kvm_host :prefix=>"stag" do
    vm "timdb001", :template=>"puppet"
    vm "merc-001", :template=>"puppet"
    vm "merc-002", :template=>"puppet"

  it would provision these three machines and because they are defined with the puppet template they would auto-run puppet and come up
  ready to run tests against.

  We could then start to automate full environment tests..

4. Auto-wiring of services within an environment.

Currently each dependant service is hand-wired in hiera or even puppet manifests, it is very time-consuming and square peg round hole
to put together a new environment. This step will make it easier to create new environments, and make testing and DR easier.

We should be able to create something that defines environments, and provides all the wiring::

location("net.local") {
  environment("stag") {
    service "timdb", :instances=>{:master=>1,:slave=>1}
    service "timweb", :instances=>{[blue,green].2}
  }
} 

produces something like (or the enc equiv):
  node "stag-timdb-001.stag.net.local" {
    role::database ...
  }
  node "stag-timweb-001.stag.net.local","stag-timweb-002.stag.net.local" {
    role::timwebserver{database_server=>"stag-timdb-001.stag.net.local"}
  }

5. Ability to provision bare-metal kvm hosts and database servers. Probably using a lightweight netboot os and then
running the same debootstrap process as for the vm's.
  
  
kvm_host :prefix=>"sel" do
  host_set "ubuntu", :range=>1.to(20), :template=>"senode", :start_grid=>true
end

kvm_host :prefix=>"sel" do
  host_set "ubuntu", :range=>21.to(40), :template=>"senode", :start_grid=>true
end

kvm_host :prefix=>"sel" do
  host_set "xp-ie6", :range=>1.to(40), :template=>"senode", :start_grid=>true, :ie_version=>6
  host_set "xp-ie7", :range=>1.to(40), :template=>"senode", :start_grid=>true, :ie_version=>7
  host_set "xp-ie8", :range=>1.to(40), :template=>"senode", :start_grid=>true, :ie_version=>8
end

kvm_host :prefix=>"stag" do
  vm "timdb001", :template=>"puppet"
end

## in a file called ldn_kvm_011
kvm_host :prefix=>"stag" do
  vm "timdb001", :template=>"puppet"
  vm "merc-001", :template=>"puppet"
  vm "merc-002", :template=>"puppet"
  vm "merc-db-001", :template=>"puppet"
  vm "merc-db-002", :template=>"puppet"
  vm "merc-db-003", :template=>"puppet"
  vm "futuresroll-001", :template=>"puppet"
  vm "futuresroll-002", :template=>"puppet"
  vm "lb-001", :template=>"puppet"
  vm "lb-002", :template=>"puppet"
end

require 'thread'

q = Queue.new

20.times { |i|
  q<<"#{i}"
}
threads = []

3.times { |i|
  threads << Thread.new {
    begin
      while ((something = q.pop(true))!=nil)
        print "t#{i} #{something}\n"
        sleep 1
      end
    rescue

    ensure
      print "t#{i} done\n"
    end
  }
}

threads.each {|thread|thread.join()}
