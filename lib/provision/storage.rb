require 'provision/logger'
require 'provision/image/commands'

class Provision::Storage
  include Provision::Image::Commands

  @@executed_tasks = {}
  @@cleanup_tasks = {}
  @@cleanup_tasks_order = {}
  @@logger = Provision::Logger.get_logger('storage')

  def initialize(options)
    @options = options
  end

  # Provision::Image:Commands uses the log function of whichever
  # class it's included in, so we need this here otherwise we break
  # that module.
  def log
    @@logger
  end

  def run_task(name, identifier, task_hash)
    begin
      @@logger.debug("Running task '#{identifier}' for '#{name}'")
      @@executed_tasks[name] = [] if @@executed_tasks[name].nil?
      @@executed_tasks[name] << identifier
      begin
        task_hash[:task].call
      rescue Exception => e
        log.debug("Run task #{identifier} on host #{name} failed with: #{e.inspect}.")
        raise e
      end
    end

    @@logger.debug("Existing cleanup tasks for #{name}: #{@@cleanup_tasks[name]}")
    @@cleanup_tasks[name] = {} if @@cleanup_tasks[name].nil?
    @@cleanup_tasks_order[name] = [] if @@cleanup_tasks_order[name].nil?

    unless task_hash[:cleanup].nil?
      @@logger.debug("Cleanup task with identifier #{identifier} nil?: #{@@cleanup_tasks[name][identifier].nil?}")
      @@logger.debug("Cleanup task with identifer #{identifier} contains: #{@@cleanup_tasks[name][identifier]}")
      raise "Tried to add cleanup task for host '#{name}' with identifier '#{identifier}' as it already exists" unless @@cleanup_tasks[name][identifier].nil?
      @@logger.debug("adding cleanup task for '#{name}' with identifier '#{identifier}'")
      @@cleanup_tasks[name][identifier] = task_hash[:cleanup]
      @@cleanup_tasks_order[name] << identifier
    end

    unless task_hash[:remove_cleanup].nil?
      tasks = task_hash[:remove_cleanup].class == Array ? task_hash[:remove_cleanup] : [task_hash[:remove_cleanup]]
      tasks.each do |id|
        @@logger.debug("removing cleanup task for '#{name}' with identifier '#{id}'")
        @@cleanup_tasks[name].delete id
        @@cleanup_tasks_order[name].delete id
      end
      @@logger.debug("Cleanup tasks left over after this process for #{name}: #{@@cleanup_tasks[name]}")
    end
  end

  def self.cleanup(name)
    @@logger.debug("starting cleanup for '#{name}'")
    unless @@executed_tasks[name].nil?
      @@executed_tasks[name].each do |id|
        @@logger.debug("Executed task: #{id}")
      end
    end
    unless @@cleanup_tasks_order[name].empty?
      @@cleanup_tasks_order[name].reverse.each do |id|
        @@logger.debug("Cleanup task: #{id}")
      end
      @@cleanup_tasks_order[name].reverse.each do |id|
        @@logger.debug("starting cleanup for '#{name}' with identifier '#{id}'")
        begin
          @@cleanup_tasks[name][id].call
        rescue Exception => e
          log.debug("Run task #{identifier} on host #{name} failed with: #{e.inspect}.")
          raise e
        end
      end
    end
    finished(name)
    @@logger.debug("finished cleanup for '#{name}'")
  end

  def self.finished(name)
    @@cleanup_tasks_order.delete name
    @@cleanup_tasks.delete name
    @@executed_tasks.delete name
  end
end

class Provision::Storage::StorageNotFoundError < StandardError
end
