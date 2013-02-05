require 'logger'
require 'provision/namespace'
require 'thread'
require 'provision/workqueue/noop_listener'
require 'provision/workqueue/curses_listener'
require 'provision/vm/virsh'

class Provision::WorkQueue
  class SpecTask
    attr_reader :spec
    def initialize(spec, &block)
      @spec = spec
      @block = block
    end

    def execute
      @block.call
    end
  end

  def initialize(args)
    @provisioning_service = args[:provisioning_service]
    @worker_count = args[:worker_count]
    @listener = args[:listener]
    @queue = Queue.new
    @logger = args[:logger] || Logger.new(STDERR)
    @virsh = args[:virsh] || Provision::VM::Virsh.new()
  end

  def launch_all(specs)
    raise "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      launch(spec)
    end
  end

  def destroy_all(specs)
    raise "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      destroy(spec)
    end
  end

  def launch(spec)
    @queue << SpecTask.new(spec) do
      @logger.info("Provisioning a VM")
      @provisioning_service.provision_vm(spec)
    end
  end

  def destroy(spec)
    if (@virsh.is_active(spec))
      @queue << SpecTask.new(spec) do
        @provisioning_service.clean_vm(spec)
      end
    end
  end

  def process()
    @logger.info("Process work queue")
    threads = []
    total = @queue.size()
    @worker_count.times {|i|
      threads << Thread.new {
        while(not @queue.empty?)
          task = @queue.pop(true)
          task.spec[:thread_number] = i
          require 'yaml'
          error = nil
          begin
            task.execute()
          rescue Exception => e
            print e.backtrace
            @listener.error(e, task.spec)
            error = e
          ensure
            @listener.passed(task.spec) if error.nil?
          end
        end
      }
    }
    threads.each {|thread| thread.join()}
  end
end
