require 'provision/namespace.rb'
require 'thread'
require 'provision/workqueue/noop_listener'
require 'provision/workqueue/curses_listener'

class Provision::WorkQueue
  def initialize(args)
    @provisioning_service = args[:provisioning_service]
    @worker_count = args[:worker_count] 
    @listener = args[:listener]
    @queue = Queue.new
  end

  def fill(specs)
    raise "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      add(spec)
    end
  end

  def add(spec)
    @queue << spec
  end

  def process()
    threads = []
    total = @queue.size()
    @worker_count.times {|i|
      threads << Thread.new {
        while(not @queue.empty?)
          spec = @queue.pop(true)
          spec[:thread_number] = i
          require 'yaml'
          begin
#            @provisioning_service.provision_vm(spec)
          rescue Exception => e
            @listener.error(e, spec)
          ensure
             @listener.passed(spec)
          end
        end
      }
    }
    threads.each {|thread| thread.join()}
  end
end
