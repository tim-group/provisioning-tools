module Provision
  class Build
    def initialize(name, options)
      @name = name
      @options = options
      @commands = []
      @cleanups = []
    end

    def run(txt, &block)
      @commands << {:txt=>txt, :block=>block}
    end

    def cleanup(&block)
      @cleanups << block
    end

    def call(method)
      call_define(method,self)
    end

    def method_missing(name,*args,&block)
      call(name.to_s())
    end

    def execute()
      position = 40
      error = nil
      begin
        @commands.each {|command|
          txt = command[:txt]
          padding =  position - txt.length
          print "#{txt}"
          padding.times {print " "}

          begin
            command[:block].call()
          rescue Exception=>e
            error = e
            raise e
          ensure
            if (not error.nil?)
              print "[\e[0;31mFAILED\e[0m]\n"
              raise error
            else
              print "[\e[0;32mDONE\e[0m]\n"
            end
          end
        }
      rescue Exception=>e
      end

      txt = "cleaning up #{@cleanups.size} blocks"
      print "#{txt}"
      padding =  position - txt.length
      padding.times {print " "}

      @cleanups.reverse.each {|command|
        begin
          command.call()
        rescue Exception=>e
          print "[\e[0;31mFAILED\e[0m]\n"
        ensure
        end
      }
      print "[\e[0;32mDONE\e[0m]\n"
      
      if error!=nil
        raise error
      end
    end

  end

  module Catalogue
    @@catalogue = {}

    def load(dir)
      Dir.entries(dir).each do |file|
        require "#{dir}/#{file}" if file =~/.rb$/
      end
    end

    def define(name, &block)
      @@catalogue[name] = block
    end

    def call_define(name, build)
      closure = @@catalogue[name]
      build.instance_eval(&closure)
      return build
    end

    def build(name, options)
      build = Provision::Build.new(name, options)
      closure = @@catalogue[name]
      build.instance_eval(&closure)
      return build
    end
  end
end

include Provision::Catalogue