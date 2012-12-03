require 'logger'

module Provision
  module Log
    def new_log()
      if (@spec!=nil and spec[:logdir]!=nil)
        @log = Logger.new("#{spec[:logdir]}/provision-#{spec.thread_number}.log")
      else
        @log = Logger.new(STDOUT)
      end
    end

    def new_cleanup_log()
      if (@spec!=nil and spec[:logdir]!=nil)
        @cleanup_log = Logger.new("#{spec[:logdir]}/cleanup_provision-#{spec.thread_number}.log")
      else
        @cleanup_log = Logger.new(STDOUT)
      end
    end

   def new_summary_log()
      if (@spec!=nil and spec[:logdir]!=nil)
        @summary_log = Logger.new("#{spec[:logdir]}/summary-#{spec.thread_number}.log")
      else
        @summary_log = Logger.new(STDOUT)
      end
    end

    def log()
      new_log() if (@log==nil)
      return @log
    end

    def cleanup_log()
      new_cleanup_log() if (@cleanup_log==nil)
      return @cleanup_log
    end

    def summary_log()
      new_summary_log() if (@summary_log==nil)
      return @summary_log
    end
  end
end
