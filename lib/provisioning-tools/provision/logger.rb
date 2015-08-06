require 'logger'
require 'fileutils'

class Provision::Logger
  @@logger = nil
  def self.get_logger(log_id = 'provision')
    if @@logger.nil?
      log_dir = '/var/log/provisioning-tools'
      unless File.directory?(log_dir) && File.writable?(log_dir)
        log_dir = '/tmp/provisioning-tools/log'
        FileUtils.mkdir_p(log_dir)
      end
      @@logger = Logger.new("#{log_dir}/#{log_id}.log", 'weekly')
    end
    @@logger
  end
end
