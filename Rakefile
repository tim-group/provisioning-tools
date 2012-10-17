require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'fileutils'
require 'rspec/core/rake_task'

task :default do
  sh "rake -s -T"
end

desc "Demonstrate load balancing by hammering the VIP."
task :hammer do
    sh "watch -n 1 'curl http://192.168.5.42 --connect-timeout 1'"
end

desc "Set up virtual network"
task :network do
    sh "sudo bash 'ext/define-net.sh' 2>/dev/null"
    sh "sudo pkill dnsmasq"
    sh "sudo bash 'ext/dnsmasq.sh'"
end

desc "Build all VMs"
task :build_all do
  sh "sudo ./bin/inventory -hlocalhost -edev -g*"
  sh "ssh-keygen -R dev-refapp-001"
  sh "ssh-keygen -R dev-refapp-002"
  sh "ssh-keygen -R dev-lb-001"
  sh "ssh-keygen -R dev-puppetmaster-001"
end

desc "Build app VMs"
task :build_app do
  sh "sudo ./bin/inventory -hlocalhost -edev -grefapp"
  sh "ssh-keygen -R dev-refapp-001"
  sh "ssh-keygen -R dev-refapp-002"
end

desc "Build loadbalancer VM"
task :build_lb do
  sh "sudo ./bin/inventory -hlocalhost -edev -glb"
  sh "ssh-keygen -R dev-lb-001"
end

desc "Build puppetmaster VM"
task :build_pm do
  sh "sudo ./bin/inventory -hlocalhost -edev -gpm"
  sh "ssh-keygen -R dev-puppetmaster-001"
end

desc "Build puppetmaster VM"
task :build_px do
  sh "sudo ./bin/inventory -hlocalhost -edev -gpx"
  sh "ssh-keygen -R dev-px-001"
end


desc "Run puppet"
task :run_puppet do
  sh "ssh-keygen -R $(dig dev-puppetmaster-001.dev.net.local @192.168.5.1 +short)"
  sh "chmod 600 files/id_rsa"
  sh "ssh -o StrictHostKeyChecking=no -i files/id_rsa root@$(dig dev-puppetmaster-001.dev.net.local @192.168.5.1 +short) 'mco puppetd runall 4'"
end

desc "Generate CTags"
task :ctags do
  sh "ctags -R --exclude=.git --exclude=build *"
end

task :test => [:setup]
Rake::TestTask.new { |t|
    t.pattern = 'test/**/*_test.rb'
}

desc "Run specs"
RSpec::Core::RakeTask.new("sys_spec") do |t|
    t.rspec_opts = %w[--color]
    t.pattern = "test/sys_spec/**/*_spec.rb"
end

desc "Run specs"
RSpec::Core::RakeTask.new() do |t|
    t.rspec_opts = %w[--color]
    t.pattern = "test/spec/**/*_spec.rb"
end

desc "On"
task :switch_on do
  `sudo virsh net-start mgmt`
  `sudo virsh net-start front`
  `sudo virsh net-start middle`
  `sudo virsh net-start back`
 
  `sudo virsh start dev-lb-001`
  `sudo virsh start dev-refapp-001`
  `sudo virsh start dev-refapp-002`
  `sudo virsh start dev-puppetmaster-001`

end
