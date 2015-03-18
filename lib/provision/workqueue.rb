require 'logger'
require 'provision/namespace'
require 'thread'
require 'provision/workqueue/noop_listener'
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
    @config = args[:config]
    @virsh = args[:virsh] || Provision::VM::Virsh.new(@config)
  end

  def launch_all(specs)
    raise "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      launch(spec)
    end
    process
  end

  def destroy_all(specs)
    raise "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      destroy(spec)
    end
    process
  end

  def allocate_ip_all(specs)
    raise "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      allocate_ip(spec)
    end
    process
  end

  def free_ip_all(specs)
    raise "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      free_ip(spec)
    end
    process
  end

  def add_cnames(specs)
    specs.each do |spec|
      @queue << SpecTask.new(spec) do
        @provisioning_service.add_cnames(spec)
      end
    end
    process
  end

  def remove_cnames(specs)
    specs.each do |spec|
      @queue << SpecTask.new(spec) do
        @provisioning_service.remove_cnames(spec)
      end
    end
    process
  end

  def launch(spec)
    @queue << SpecTask.new(spec) do
      @logger.info("Provisioning a VM")
      @provisioning_service.provision_vm(spec)
    end
  end

  def destroy(spec)
    if @virsh.is_defined(spec)
      @queue << SpecTask.new(spec) do
        @provisioning_service.clean_vm(spec)
      end
    end
  end

  def allocate_ip(spec)
    @queue << SpecTask.new(spec) do
      @provisioning_service.allocate_ip(spec)
    end
  end

  def free_ip(spec)
    @queue << SpecTask.new(spec) do
      @provisioning_service.free_ip(spec)
    end
  end

  def process
    @logger.info("Process work queue")
    threads = []
    total = @queue.size
    @worker_count.times do|i|
      threads << Thread.new do
        while !@queue.empty?
          task = @queue.pop(true)
          task.spec[:thread_number] = i
          require 'yaml'
          error = nil
          begin
            msg = task.execute
          rescue Exception => e
            print e.backtrace
            @listener.error(task.spec, e)
            error = e
          ensure
            @listener.passed(task.spec, msg) if error.nil?
          end
        end
      end
    end
    threads.each { |thread| thread.join }
  end
end
