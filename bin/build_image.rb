#!/usr/bin/ruby
$: << File.join(File.dirname(__FILE__), "..", "lib")

configdir = File.join(File.dirname(__FILE__), "../lib/config")
target_dir = File.join(File.dirname(__FILE__), "../target")

if Process.uid != 0
  raise 'FATAL: Process needs to run as root!'
end 

require 'optparse'
require 'provision/catalogue'

template = nil
hostname = nil
Provision::Catalogue::load(configdir)
@option_parser = OptionParser.new do|opts|
      opts.banner =
"Usage: provision --template ubuntuprecise --hostname mymachine"
      opts.on("-t","--template TEMPLATE", "specify the template to use") do |template_p|
        template = template_p
      end
      opts.on("-h","--hostname HOSTNAME", "specify the template to use") do |hostname_p|
        hostname = hostname_p
      end
end
@option_parser.parse!

if (template ==nil || hostname == nil)
  print  @option_parser.help()
  exit
end

build = Provision::Catalogue::build(template, {:hostname=>hostname})
Dir.chdir(target_dir)
build.execute()