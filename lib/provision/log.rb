require 'logger'

require 'provision/namespace'

module Provision
  module Log
    def new_log()
      if (@spec != nil)
        @log = spec.get_logger('provision')
      else
        @log = Logger.new(STDOUT)
      end
    end

    def log()
      new_log() if (@log == nil)
      return @log
    end
  end
end
