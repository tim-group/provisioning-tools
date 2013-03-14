require 'provision/image/namespace'
require 'provision/log'

class Provision::Image::Build
  include Provision::Log
  attr_accessor :spec
  attr_accessor :supress_error

  def initialize(name, spec)
    @name = name
    @spec = spec
    @commands = []
    @cleanups = []
    @supress_error = CatchAndIgnore.new(self)
  end

  def console_log()
    return spec[:console_log] || "console.log"
  end

  def run(txt, &block)
    @commands << {:txt=>txt, :block=>block}
  end

  def cleanup(&block)
    @cleanups <<  lambda {
      supress_error.instance_eval(&block)
    }
  end

  def call(method)
    call_define(method, self)
  end

  def method_missing(name,*args,&block)
    call(name.to_s())
  end

  def execute()
    position = 40
    error = nil
    trap("SIGINT") { throw :ctrl_c }

    begin
      @commands.each {|command|
        txt = command[:txt]
        padding =  position - txt.length
        summary_log.info "#{txt}"
        start = Time.new

        begin
          command[:block].call()
        rescue Exception=>e
          error = e
          raise e
        ensure
          if (not error.nil?)
            summary_log.info "[\e[0;31mFAILED\e[0m]\n"
            raise error
          else
            elapsed_time = Time.now-start
            summary_log.info "[\e[0;32mDONE in #{elapsed_time*1000}ms\e[0m]\n"
          end
        end
      }
    rescue Exception=>e
      summary_log.info e
      log.error(e)
    end

    txt = "cleaning up #{@cleanups.size} blocks"
    summary_log.info "#{txt}"
    padding =  position - txt.length
    @cleanups.reverse.each {|command|
      begin
        command.call()
      rescue Exception=>e
        cleanup_log.error(e)
      ensure
      end
    }
    summary_log.info "[\e[0;32mDONE\e[0m]\n"

    if error!=nil
      raise error
    end
  end

  def summary_log()
    @summary_log ||= @spec.get_logger('summary')
  end
  def cleanup_log()
    @cleanup_log ||= @spec.get_logger('cleanup_provision')
  end
end

class CatchAndIgnore
  attr_accessor :build
  def initialize(build)
    @build = build
  end

  def console_log()
    return "#{spec[:console_log]}.suppressed"
  end

  def method_missing(name,*args,&block)
    begin
      result = @build.send name, *args, &block
      return result
    rescue Exception=>e
      cleanup_log.error("error sending #{name}")
      cleanup_log.error(e)
      return nil
    end
  end
end

