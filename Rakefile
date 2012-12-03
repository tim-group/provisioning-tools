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
  sh "sudo pkill dnsmasq"
  sh "sudo bash 'networking/define-net.sh'"
  sh "sudo pkill dnsmasq"
  sh "sudo bash 'networking/dnsmasq.sh'"
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
    t.pattern = "spec/**/*_spec.rb"
end

desc "Generate deb"
task :package do
    sh "rm *.deb *.gem"
    sh "gem build provisioning-tools.gemspec"
    sh "fpm -s gem -t deb provisioning-tools-*.gem"
end

