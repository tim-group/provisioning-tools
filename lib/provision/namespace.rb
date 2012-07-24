require 'logger'
module Provision

  module Log
    def new_log()
      @log = Logger.new("#{@logdir}/provision-#{@thread_number}.log")
    end

    def new_summary_log()
      @summary_log = Logger.new("#{@logdir}/summary-#{@thread_number}.log")
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
