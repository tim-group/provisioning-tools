require 'provision/log'
require 'provision/image/commands'

class Provision::Storage
  include Provision::Image::Commands
  include Provision::Log
  extend Provision::Log

  @@cleanup_tasks = {}

  def initialize(options)
    @options = options
  end

  def run_task(name, task_hash)
    begin
      task_hash[:task].call
    rescue Exception=>e
      begin
        task_hash[:on_error].call unless task_hash[:on_error].nil?
      ensure
        raise e
      end
    end
    unless task_hash[:cleanup].nil?
      @@cleanup_tasks[name] = [] if @@cleanup_tasks[name].nil?
      @@cleanup_tasks[name] << task_hash[:cleanup]
      log.debug("added cleanup task")
    end
  end

  def self.cleanup(name)
    log.debug("starting cleanup")
    unless @@cleanup_tasks[name].nil?
      @@cleanup_tasks[name].reverse.each do |cleanup_task|
        cleanup_task.call
      end
    end
    @@cleanup_tasks[name] = []
    log.debug("finished cleanup")
  end
end
