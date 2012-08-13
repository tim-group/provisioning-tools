require 'provision/namespace.rb'
require 'thread'
require 'provision/workqueue/noop_listener'
require 'provision/workqueue/curses_listener'

class Provision::WorkQueue
  def initialize(args)
    @provisioning_service = args[:provisioning_service]
    @worker_count = args[:worker_count] 
    @listener = args[:listener]||  NoopListener.new()
    @queue = Queue.new
  end

  def add(spec)
    @queue << spec
  end

  def process()
    threads = []
    total = @queue.size()
    completed = 0
    errors = 0
    thread_progress = []
    @listener.update(:errors=>errors, :completed=>completed)
    @worker_count.times {|i|
      threads << Thread.new {
        while(not @queue.empty?)
          spec = @queue.pop(true)
          spec[:thread_number] = i
          require 'yaml'
          thread_progress[i] = spec
          begin
            @provisioning_service.provision_vm(spec)
          rescue Exception => e
            errors+=1
            print e
            @listener.error(e)
          ensure
            completed+=1
            @listener.update(:errors=>errors, :completed=>completed)
          end
        end
      }
    }
    threads.each {|thread| thread.join()}
  end
end
