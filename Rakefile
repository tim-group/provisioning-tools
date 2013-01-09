require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'fileutils'
require 'rspec/core/rake_task'

task :default do
  sh "rake -s -T"
end

desc "Set up virtual network"
task :network do
  sh "sudo killall -0 dnsmasq; if [ $? -eq 0 ]; then sudo pkill dnsmasq; fi"
  sh "sudo bash 'networking/numbering_service.sh'"
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

desc "Run specs"
RSpec::Core::RakeTask.new() do |t|
  t.rspec_opts = %w[--color]
  t.pattern = "spec/provision/**/*_spec.rb"
end

desc "MCollective Run specs"
RSpec::Core::RakeTask.new(:mcollective_spec) do |t|
  t.rspec_opts = %w[--color]
  t.pattern = "spec/mcollective/**/*_spec.rb"
end

desc "Clean everything up"
task :clean do
  sh "rm -rf build"
end

desc "Generate deb file for the gem and command-line tools"
task :package_main do
  sh "mkdir -p build"
  sh "if [ -f *.gem ]; then rm *.gem; fi"
  sh "cd build && gem build ../provisioning-tools.gemspec"
  sh "cd build && fpm -s gem -t deb provisioning-tools-*.gem"
end

desc "Generate deb file for the MCollective agent"
task :package_agent do
  sh "echo I AM PACKAGING THE MCO AGENT"
end

task :package => [:package_main, :package_agent]

task :test => [:spec, :mcollective_spec]

