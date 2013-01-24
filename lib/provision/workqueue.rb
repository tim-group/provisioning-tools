require 'logger'
require 'provision/namespace'
require 'thread'
require 'provision/workqueue/noop_listener'
require 'provision/workqueue/curses_listener'

class Provision::WorkQueue
  def initialize(args)
    @provisioning_service = args[:provisioning_service]
    @worker_count = args[:worker_count]
    @listener = args[:listener]
    @queue = Queue.new
    @logger = args[:logger] || Logger.new(STDERR)
  end

  def fill(specs)
    @logger.info("Fill work queue")
    raise "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      add(spec)
    end
  end

  def add(spec)
    @queue << spec
  end

  def clean()
    threads = []
    total = @queue.size()
    @worker_count.times {|i|
      threads << Thread.new {
        while(not @queue.empty?)
          spec = @queue.pop(true)
          spec[:thread_number] = i
          require 'yaml'
          error = nil
          begin
            @provisioning_service.clean_vm(spec)
          rescue Exception => e
            print e.backtrace
            @listener.error(e, spec)
            error = e
          ensure
             @listener.passed(spec) if error.nil?
          end
        end
      }
    }
    threads.each {|thread| thread.join()}
  end

  def process()
    @logger.info("Process work queue")
    threads = []
    total = @queue.size()
    @worker_count.times {|i|
      threads << Thread.new {
        while(not @queue.empty?)
          spec = @queue.pop(true)
          spec[:thread_number] = i
          require 'yaml'
          error = nil
          begin
            @logger.info("Provisioning a VM")
            @provisioning_service.provision_vm(spec)
          rescue Exception => e
            print e.backtrace
            @listener.error(e, spec)
            error = e
          ensure
             @listener.passed(spec) if error.nil?
          end
        end
      }
    }
    threads.each {|thread| thread.join()}
  end
end
