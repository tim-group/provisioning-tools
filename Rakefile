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
  sh "killall -0 dnsmasq; if [ $? -eq 0 ]; then sudo pkill dnsmasq; fi"
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


desc "Generate deb"
task :package do
    sh "if [ -f *.deb ]; then rm *.deb; fi"
    sh "if [ -f *.gem ]; then rm *.gem; fi"
    sh "gem build provisioning-tools.gemspec"
    sh "fpm -s gem -t deb provisioning-tools-*.gem"
end

task :test => [:spec, :mcollective_spec]

