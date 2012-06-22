require 'logger'

module Provision
  @@log = Logger.new("provision.log")
  def self.log()
    return @@log
  end

  class CatchAndIgnore
    attr_accessor :build
    def initialize(build)
      @build = build
    end

    def method_missing(name,*args,&block)

      print "SEND #{name} #{args}\n"

      begin
        @build.send name, *args
      rescue Exception=>e
        Provision.log.error(e)
      end
    end
  end

  class Build
    attr_accessor :supress_error
    def initialize(name, options)
      @name = name
      @options = options
      @commands = []
      @cleanups = []
      @supress_error = CatchAndIgnore.new(self)
    end

    def makevar(var,value)
      @mine="hello"
      @mine2="hello2"
      var_string = var.to_s()
      inst_variable_name = "@#{var_string}".to_sym
      setter = "#{var_string}ll"
      print ">>#{setter}..@cleanups.....................\n"

      singleton = class << self; self end
      singleton.send :define_method, setter, lambda { |new_value|
        print "EEEEEEEEEEEEEEEEEEEEEEEEEEEE #{new_value} \n"
      }

      singleton.send :define_method, var_string, lambda { return instance_variable_get(inst_variable_name)}
    end

    def setvar(var,new_value)
      inst_variable_name = "@#{var}".to_sym
      instance_variable_set inst_variable_name, new_value
    end

    def getvar(var)
      inst_variable_name = "@#{var}".to_sym
      return instance_variable_get(inst_variable_name)
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
        Provision.log.error(e)
      end

      txt = "cleaning up #{@cleanups.size} blocks"
      print "#{txt}"
      padding =  position - txt.length
      padding.times {print " "}
      @cleanups.reverse.each {|command|
        begin
          command.call()
        rescue Exception=>e
          Provision.log.error(e)
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

    def list_templates()
      return @@catalogue.keys()
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