require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'fileutils'
require 'rspec/core/rake_task'
require 'fpm'

def build_deb()
  $: << File.join(File.dirname(__FILE__), "..", "..", "lib")

  package = FPM::Package::Gem.new
  package.input(ARGV[0])
  rpm = package.convert(FPM::Package::RPM)
  begin
    output = "NAME-VERSION.ARCH.rpm"
    rpm.output(rpm.to_s(output))
  ensure
    rpm.cleanup
  end
end


task :default do
  sh "rake -s -T"
end

desc "Set up virtual network"
task :network do
  sh "sudo killall -0 dnsmasq; if [ $? -eq 0 ]; then sudo pkill dnsmasq; fi"
  sh "sudo bash 'networking/numbering_service.sh'"
end

desc "Build Gold Image"
task :build_gold do
  sh "mkdir -p build/gold"
  $: << File.join(File.dirname(__FILE__), "./lib")
  require 'yaml'
  require 'provision'
  require 'pp'

  dest = File.dirname(__FILE__) + '/build/gold'
  result = Provision::Factory.new.create_gold_image({:spindle=>dest, :hostname=>"generic"})
  sh "chmod a+w -R build"
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

desc "MCollective Run specs"
RSpec::Core::RakeTask.new(:mcollective_spec) do |t|
  t.rspec_opts = %w[--color]
  t.pattern = "mcollective/spec/**/*_spec.rb"
end

desc "Clean everything up"
task :clean do
  sh "rm -rf build"
end

desc "Generate deb file for the gem and command-line tools"
task :package_main do
  sh "mkdir -p build"
  sh "if [ -f *.gem ]; then rm *.gem; fi"
  sh "gem build provisioning-tools.gemspec && mv provisioning-tools-*.gem build/"
  sh "cp postinst.sh build/"

  commandLine = "cd build",
    "&&",
    "fpm",
    "-s", "gem",
    "-t", "deb",
    "-n", "provisioning-tools",
    "-d", "provisioning-tools-gold-image",
    "-d", "debootstrap",
    "provisioning-tools-*.gem"

  sh commandLine.join(' ')
end

desc "Generate deb file for the Gold image"
task :package_gold do
  hash = `git rev-parse --short HEAD`.chomp
  v_part= ENV['BUILD_NUMBER'] || "0.#{hash.hex}"
  version = "0.0.#{v_part}"

  commandLine  = "fpm",
    "-s", "dir",
    "-t", "deb",
    "-n", "provisioning-tools-gold-image",
    "-v", version,
    "-a", "all",
    "-C", "build",
    "-p", "build/provisioning-tools-gold-image_#{version}.deb",
    "--prefix", "/var/local/images/",
    "gold"

  sh commandLine.join(' ')
end

desc "Generate deb file for the MCollective agent"
task :package_agent do
  sh "mkdir -p build"
  hash = `git rev-parse --short HEAD`.chomp
  v_part= ENV['BUILD_NUMBER'] || "0.#{hash.hex}"
  version = "0.0.#{v_part}"

  commandLine  = "fpm",
    "-s", "dir",
    "-t", "deb",
    "-n", "provisioning-tools-mcollective-plugin",
    "-v", version,
    "-d", "provisioning-tools",
    "-d", "provisioning-tools-mcollective-plugin-ddl",
    "-a", "all",
    "-C", "build",
    "-p", "build/provisioning-tools-mcollective-plugin_#{version}.deb",
    "--prefix", "/usr/share/mcollective/plugins/mcollective",
    "--post-install", "postinst.sh",
    "-x", "agent/*.ddl",
    "../mcollective/agent"

  sh commandLine.join(' ')

  commandLine  = "fpm",
    "-s", "dir",
    "-t", "deb",
    "-n", "provisioning-tools-mcollective-plugin-ddl",
    "-v", version,
    "-a", "all",
    "-C", "build",
    "-p", "build/provisioning-tools-mcollective-plugin-ddl_#{version}.deb",
    "--prefix", "/usr/share/mcollective/plugins/mcollective",
    "-x", "agent/*.rb",
    "../mcollective/agent"

  sh commandLine.join(' ')



  #      '-m',"youDevise <support@timgroup.com>",
  #      '--description',"TIM Account Management Report Tool (Import)",
  #      '--pre-install','build-scripts/deb-pre-install.rb',
  #      '--post-install','build-scripts/deb-post-install.rb',
  #      '-C','build/package',
end

task :package => [:clean, :package_main, :package_agent]
task :install => [:package] do
   sh "sudo dpkg -i build/*.deb"
end
task :test => [:spec, :mcollective_spec]

