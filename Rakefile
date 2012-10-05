require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'fileutils'
require 'rspec/core/rake_task'

task :default do
  sh "rake -s -T"
end

task :thing do
    sh "sudo pwd"
end

desc "Set up virtual network"
task :network do
    sh "sudo bash 'ext/define-net.sh' 2>/dev/null"
    sh "sudo pkill dnsmasq"
    sh "sudo bash 'ext/dnsmasq.sh'"
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

desc "Run puppet"
task :run_puppet do
  sh "ssh -o StrictHostKeyChecking=no root@dev-puppetmaster-001 'mco puppetd runall 4'"
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
