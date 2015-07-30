#!/opt/ruby-bundle/bin/ruby

require 'json'

$: << '/opt/provisioning-tools/lib/ruby/site_ruby'
$: << '/usr/local/lib/site_ruby/timgroup/'
require 'provisioning-tools/provision'
require 'provisioning-tools/provision/workqueue'
require 'provisioning-tools/util/symbol_utils'

mco_args  = JSON.parse(File.read(ARGV[0]), :symbolize_names => true)
mco_reply = {}

@logger = Logger.new(STDOUT)

def provisioner
  Provision::Factory.new(:logger => @logger)
end

def prepare_work_queue(specs, listener)
  work_queue = provisioner.work_queue(:worker_count => 1, :listener => listener)

  symbol_utils = ::Util::SymbolUtils.new
  specs = specs.map { |spec| symbol_utils.symbolize_keys(spec) }

  work_queue
end

def provision(specs, listener)
  @logger.info("Launching #{specs.size} nodes")
  queue = prepare_work_queue(specs, listener)
  queue.launch_all(specs)
  listener.results
end

def clean(specs, listener)
  queue = prepare_work_queue(specs, listener)
  @logger.info("Cleaning #{specs.size} nodes")
  queue.destroy_all(specs)

  listener.results
end

def allocate_ips(specs, listener)
  queue = prepare_work_queue(specs, listener)
  @logger.info("Allocating IP addresses for #{specs.size} nodes")
  queue.allocate_ip_all(specs)

  listener.results
end

def free_ips(specs, listener)
  queue = prepare_work_queue(specs, listener)
  @logger.info("Freeing IP addresses for #{specs.size} nodes")
  queue.free_ip_all(specs)

  listener.results
end

def add_cnames(specs, listener)
  queue = prepare_work_queue(specs, listener)
  @logger.info("Adding CNAME's #{specs}")
  queue.add_cnames(specs)

  listener.results
end

def remove_cnames(specs, listener)
  queue = prepare_work_queue(specs, listener)
  @logger.info("Removing CNAME's for #{specs.size} nodes")
  queue.remove_cnames(specs)

  listener.results
end

def new_listener
  NoopListener.new(:logger => @logger)
end

def with_lock(&action)
  File.open('/var/lock/provision.lock', 'w') do |f|
    f.flock(File::LOCK_EX)
    action.call
  end
rescue Exception => e
  @logger.error(e)
  { "error" => e.message, "backtrace" => e.backtrace }
end

specs = mco_args[:data][:specs]
# XXX there is a lack of consistensy with regards to using strings and symbols in the "specs" hash.
#     it seems that this hash is passed around from stackbuilder-config, via stackbuilder, via mcollective to
#     provisioning-tools. all keys seem to be symbols, while most values are strings. :networks appears to be the
#     exception, though there may be others. ruby's json library does not distinguish between strings and symbols,
#     and thus the conversion must be made manually. this can lead to hard to debug problems.
specs.each { |s| s[:networks].map!(&:to_sym) } unless mco_args[:action] == 'hello'

mco_reply = case mco_args[:action]
            when 'launch'        then with_lock { provision(specs, new_listener) }
            when 'clean'         then with_lock { clean(specs, new_listener) }
            when 'allocate_ips'  then allocate_ips(specs, new_listener)
            when 'free_ips'      then free_ips(specs, new_listener)
            when 'add_cnames'    then add_cnames(specs, new_listener)
            when 'remove_cnames' then remove_cnames(specs, new_listener)
            end

File.open(ARGV[1], 'w') do |f|
  f.write(mco_reply.to_json)
end
