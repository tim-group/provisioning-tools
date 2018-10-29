require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'fileutils'
require 'rspec/core/rake_task'
require 'fpm' # needed for Dir.mktmpdir

v = ENV['BUILD_NUMBER'] || "0.#{`git rev-parse --short HEAD`.chomp.hex}"
@version = "0.0.#{v}"

task :default do
  sh "rake -s -T"
end

desc "Set up virtual network"
task :network do
  sh "sudo killall -0 dnsmasq; if [ $? -eq 0 ]; then sudo pkill dnsmasq; fi"
  sh "sudo bash 'networking/numbering_service.sh'"
end

# XXX git grep build_gold_precise in jenkins-backups returns no matches
desc "Build Precise Gold Image"
task :build_gold_precise do
  sh "mkdir -p build/gold-precise"
  require 'yaml'
  require 'provisioning-tools/provision'

  dest = File.dirname(__FILE__) + '/build/gold-precise'
  result = Provision::Factory.new.create_gold_image(:spindle => dest, :hostname => "generic", :distid => "ubuntu",
                                                    :distcodename => "precise")
  sh "chmod a+w -R build"
end

desc "Generate deb file for the Precise Gold image"
task :package_gold_precise => [:package_main] do
  command_line = "fpm",
                 "-s", "dir",
                 "-t", "deb",
                 "-n", "provisioning-tools-gold-image-precise",
                 "-v", @version,
                 "-a", "all",
                 "-C", "build",
                 "-p", "build/provisioning-tools-gold-image-precise_#{@version}.deb",
                 "--prefix", "/var/local/images/",
                 "gold-precise"

  sh command_line.join(' ')
end

desc "Run specs"
RSpec::Core::RakeTask.new

desc "MCollective Run specs"
RSpec::Core::RakeTask.new(:mcollective_spec) do |t|
  t.rspec_opts = %w(--color)
  t.pattern = "mcollective/spec/**/*_spec.rb"
end

desc 'Clean up the build directory'
task :clean do
  sh 'rm -rf build'
end

desc "Create provisioning-tools Debian package"
task :package_main do
  sh 'rm -rf build/package'
  sh 'mkdir -p build/package/usr/local/lib/site_ruby/timgroup/'
  sh 'cp -r lib/* build/package/usr/local/lib/site_ruby/timgroup/'

  sh 'mkdir -p build/package/usr/local/bin/'
  sh 'cp -r bin/* build/package/usr/local/bin/'

  arguments = [
    '--description', 'provisioning tools',
    '--url', 'https://github.com/tim-group/provisioning-tools',
    '-p', "build/provisioning-tools_#{@version}.deb",
    '-n', 'provisioning-tools',
    '-v', "#{@version}",
    '-m', 'Infrastructure <infra@timgroup.com>',
    '-d', 'debootstrap',
    '-d', 'ruby-bundle',
    '-a', 'all',
    '-t', 'deb',
    '-s', 'dir',
    '-C', 'build/package'
  ]

  argv = arguments.map { |x| "'#{x}'" }.join(' ')
  sh 'rm -f build/provisioning-tools_*.deb'
  sh "fpm #{argv}"
end

desc "Generate computenode MCollective agent and DDL packages"
task :package_agent => [:package_main] do
  arguments = [
    '--description', 'provisioning tools mcollective agent',
    '-s', 'dir',
    '-t', 'deb',
    '-n', 'provisioning-tools-mcollective-plugin',
    '-v', "#{@version}",
    '-d', 'ruby-bundle',
    # '-d', 'provisioning-tools', # XXX fix after all this repackaging has settled
    '-d', 'provisioning-tools-mcollective-plugin-ddl',
    '-a', 'all',
    '-C', 'build',
    '-p', "build/provisioning-tools-mcollective-plugin_#{@version}.deb",
    '--prefix', '/usr/share/mcollective/plugins/mcollective',
    '--post-install', 'postinst.sh',
    '-x', 'agent/*.ddl',
    '../mcollective/agent'
  ]

  argv = arguments.map { |x| "'#{x}'" }.join(' ')
  sh 'rm -f build/provisioning-tools-mcollective-plugin_*.deb'
  sh "fpm #{argv}"

  arguments = [
    '--description', 'provisioning tools mcollective agent (.ddl files)',
    '-s', 'dir',
    '-t', 'deb',
    '-n', 'provisioning-tools-mcollective-plugin-ddl',
    '-v', "#{@version}",
    '-a', 'all',
    '-C', 'build',
    '-p', "build/provisioning-tools-mcollective-plugin-ddl_#{@version}.deb",
    '--prefix', '/usr/share/mcollective/plugins/mcollective',
    '-x', 'agent/*.rb',
    '../mcollective/agent'
  ]

  argv = arguments.map { |x| "'#{x}'" }.join(' ')
  sh 'rm -f build/provisioning-tools-mcollective-plugin-ddl_*.deb'
  sh "fpm #{argv}"
end

desc 'Create all packages (prov-tools, computenode agent, computenode DDLs)'
task :package => [:clean, :package_main, :package_agent]
desc 'build and install packages locally'
task :install => [:package] do
  sh 'sudo dpkg -i build/*.deb'
end

task :test => [:spec, :mcollective_spec]

desc "Generate CTags"
task :ctags do
  sh "ctags -R --exclude=.git --exclude=build ."
end

desc 'Run lint (Rubocop)'
task :lint do
  sh 'rubocop'
end
