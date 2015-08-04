require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'fileutils'
require 'rspec/core/rake_task'
require 'fpm' # needed for Dir.mktmpdir

task :default do
  sh "rake -s -T"
end

desc "Set up virtual network"
task :network do
  sh "sudo killall -0 dnsmasq; if [ $? -eq 0 ]; then sudo pkill dnsmasq; fi"
  sh "sudo bash 'networking/numbering_service.sh'"
end

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

desc "Build Trusty Gold Image"
task :build_gold_trusty do
  sh "mkdir -p build/gold-trusty"
  require 'yaml'
  require 'provisioning-tools/provision'

  dest = File.dirname(__FILE__) + '/build/gold-trusty'
  result = Provision::Factory.new.create_gold_image(:spindle => dest, :hostname => "generic", :distid => "ubuntu",
                                                    :distcodename => "trusty")
  sh "chmod a+w -R build"
end

# XXX what's this for?
desc "Run puppet"
task :run_puppet do
  sh "ssh-keygen -R $(dig dev-puppetmaster-001.dev.net.local @192.168.5.1 +short)"
  sh "chmod 600 files/id_rsa"
  sh "ssh -o StrictHostKeyChecking=no -i files/id_rsa root@$(dig dev-puppetmaster-001.dev.net.local @192.168.5.1 " \
     "+short) 'mco puppetd runall 4'"
end

desc "Generate CTags"
task :ctags do
  sh "ctags -R --exclude=.git --exclude=build ."
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

desc "Create Debian package"
task :package_main do
  version = "1.0.#{ENV['BUILD_NUMBER']}" # XXX 1.0 -> 0.0

  sh 'rm -rf build/package'
  sh 'mkdir -p build/package/usr/local/lib/site_ruby/timgroup/'
  sh 'cp -r lib/* build/package/usr/local/lib/site_ruby/timgroup/'

  sh 'mkdir -p build/package/usr/local/bin/'
  sh 'cp -r bin/* build/package/usr/local/bin/'

  arguments = [
    '--description', 'provisioning tools',
    '--url', 'https://github.com/tim-group/provisioning-tools',
    '-p', "build/provisioning-tools-transition_#{version}.deb",
    '-n', 'provisioning-tools-transition',
    '-v', "#{version}",
    '-m', 'Infrastructure <infra@timgroup.com>',
    '-d', 'provisioning-tools-gold-image-precise',
    '-d', 'debootstrap',
    '-d', 'ruby-bundle',
    '-a', 'all',
    '-t', 'deb',
    '-s', 'dir',
    '-C', 'build/package'
  ]

  argv = arguments.map { |x| "'#{x}'" }.join(' ')
  sh 'rm -f build/*.deb'
  sh "fpm #{argv}"
end

desc "Generate deb file for the Precise Gold image"
task :package_gold_precise do
  hash = `git rev-parse --short HEAD`.chomp
  v_part = ENV['BUILD_NUMBER'] || "0.#{hash.hex}"
  version = "0.0.#{v_part}"

  command_line = "fpm",
                 "-s", "dir",
                 "-t", "deb",
                 "-n", "provisioning-tools-gold-image-precise",
                 "-v", version,
                 "-a", "all",
                 "-C", "build",
                 "-p", "build/provisioning-tools-gold-image-precise_#{version}.deb",
                 "--prefix", "/var/local/images/",
                 "gold-precise"

  sh command_line.join(' ')
end

desc "Generate deb file for the Trusty Gold image"
task :package_gold_trusty do
  hash = `git rev-parse --short HEAD`.chomp
  v_part = ENV['BUILD_NUMBER'] || "0.#{hash.hex}"
  version = "0.0.#{v_part}"

  command_line = "fpm",
                 "-s", "dir",
                 "-t", "deb",
                 "-n", "provisioning-tools-gold-image-trusty",
                 "-v", version,
                 "-a", "all",
                 "-C", "build",
                 "-p", "build/provisioning-tools-gold-image-trusty_#{version}.deb",
                 "--prefix", "/var/local/images/",
                 "gold-trusty"
  sh command_line.join(' ')
end

desc "Generate deb file for the MCollective agent"
task :package_agent do
  sh "mkdir -p build"
  hash = `git rev-parse --short HEAD`.chomp
  v_part = ENV['BUILD_NUMBER'] || "0.#{hash.hex}"
  version = "0.0.#{v_part}"

  command_line = "fpm",
                 '--description', 'provisioning tools mcollective agent',
                 "-s", "dir",
                 "-t", "deb",
                 "-n", "provisioning-tools-mcollective-plugin",
                 "-v", version,
                 "-d", "ruby-bundle",
                 # "-d", "provisioning-tools", # XXX fix after all this repackaging has settled
                 "-d", "provisioning-tools-mcollective-plugin-ddl",
                 "-a", "all",
                 "-C", "build",
                 "-p", "build/provisioning-tools-mcollective-plugin_#{version}.deb",
                 "--prefix", "/usr/share/mcollective/plugins/mcollective",
                 "--post-install", "postinst.sh",
                 "-x", "agent/*.ddl",
                 "../mcollective/agent"

  sh command_line.join(' ')

  command_line = "fpm",
                 '--description', 'provisioning tools mcollective agent (.ddl files)',
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

  sh command_line.join(' ')
end

task :package => [:clean, :package_main, :package_agent]
task :install => [:package] do
  sh "sudo dpkg -i build/*.deb"
end
task :test => [:spec, :mcollective_spec]

desc "Prepare for an omnibus run"
task :omnibus_prep do
  sh "rm -rf /opt/provisioning-tools" # XXX very bad
  sh "mkdir -p /opt/provisioning-tools"
  sh "chown \$SUDO_UID:\$SUDO_GID /opt/provisioning-tools"
end

task :omnibus do
  sh "rm -rf build/omnibus"

  sh "mkdir -p build/omnibus"
  sh "mkdir -p build/omnibus/bin"
  sh "mkdir -p build/omnibus/lib/ruby/site_ruby"
  sh "mkdir -p build/omnibus/embedded/lib/ruby" # XXX
  sh "mkdir -p build/omnibus/embedded/lib/ruby/site_ruby"
  sh "mkdir -p build/omnibus/embedded/share/provisioning-tools"

  sh "cp -r bin/* build/omnibus/bin"
  sh "cp -r lib/* build/omnibus/embedded/lib/ruby/site_ruby"
  sh "cp -r home build/omnibus/embedded/share/provisioning-tools"
  sh "cp -r templates build/omnibus/embedded/share/provisioning-tools"
  sh "cp -r files build/omnibus/embedded/share/provisioning-tools"
  sh "cp -r test build/omnibus/embedded/share/provisioning-tools"
  # expose provisioning-tools libs; required by mcollective agents
  sh "ln -s ../../../embedded/lib/ruby/site_ruby/provisioning-tools build/omnibus/lib/ruby/site_ruby/provisioning-tools"
  sh "ln -s ../../embedded/share/provisioning-tools/templates build/omnibus/lib/ruby/templates" # XXX self.templatedir
  sh "ln -s ../../embedded/share/provisioning-tools/home build/omnibus/lib/ruby/home" # XXX self.homedir
end

desc "Run lint (Rubocop)"
task :lint do
  sh "/var/lib/gems/1.9.1/bin/rubocop --require rubocop/formatter/checkstyle_formatter --format " \
     "RuboCop::Formatter::CheckstyleFormatter --out tmp/checkstyle.xml"
end
