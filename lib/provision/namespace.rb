require 'logger'

module Provision
  module Log
    def new_log()
      if (@spec!=nil)
        @log = spec.get_logger('provision')
      else
        @log = Logger.new(STDOUT)
      end
    end

    def new_cleanup_log()
      if (@spec!=nil)
        @cleanup_log = spec.get_logger('cleanup_provision')
      else
        @cleanup_log = Logger.new(STDOUT)
      end
    end

   def new_summary_log()
      if (@spec!=nil)
        @summary_log = spec.get_logger('summary')
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

