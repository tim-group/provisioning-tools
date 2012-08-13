require 'logger'

module Provision
  module Log
    def new_log()
      if (@logdir!=nil)
        @log = Logger.new("#{@logdir}/provision-#{@thread_number}.log")
      else
        @log = Logger.new(STDOUT)
      end
    end

    def new_summary_log()
      if (@logdir!=nil)
        @summary_log = Logger.new("#{@logdir}/summary-#{@thread_number}.log")
      else
        @summary_log = Logger.new(STDOUT)
      end
    end

    def log()
      new_log() if (@log==nil)
      return @log
    end

    def summary_log()
      new_summary_log() if (@summary_log==nil)
      return @summary_log
    end
  end
end
