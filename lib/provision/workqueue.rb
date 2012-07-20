require 'provision/namespace.rb'
require 'thread'

class Provision::WorkQueue
  def initialize(args)
    @provisioning_service = args[:provisioning_service]
    @worker_count = 4
    @queue = Queue.new
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
	  print "MBUILD >>> #{spec.to_yaml} \n"

          @provisioning_service.provision_vm(spec)
        end
      }
    }

    threads << Thread.new {
      while(not @queue.empty?)
        print "completed: #{total-@queue.size} / #{total} machines\n"
        sleep 1
      end
    }

    threads.each {|thread| thread.join()}
  end
end
