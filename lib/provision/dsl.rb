require 'provision/namespace'
require 'provision/template'
require 'provision/commands'
require 'yaml'

class Provision::DSL
  def initialize(args={})
    @run_blocks = []
    @cleanup_blocks = []
    @templates = {}
    @commands = args[:commands] || Provision::Commands.new()
  end

  def define(name, &block)
    @templates[name] = block
  end

  def method_missing(method, *args, &block)
    template(method.to_s, &block)
  end

  def template(name, &block)
    temp = @templates[name]
    temp.call(block)
  end

  def execute(options)
    begin
      @run_blocks.each {|block|
        print "#{block[:txt]}\t\t\t"
        error = nil
        begin
          yaml_options = YAML::dump(options)
          block[:block].binding.eval("options=YAML::load('#{yaml_options}')")
          @commands.instance_eval(&block[:block])
        rescue Exception=>e

          print e.backtrace
          error =e
        end
        if (not error.nil?)
          print "[\e[0;31mFAILED\e[0m]\n"
          raise error
        else
          print "[\e[0;32mDONE\e[0m]\n"
        end
      }
    rescue Exception=>e
    ensure
      print "cleaning up\t\t\t"
      @cleanup_blocks.reverse.each {|block|
        begin
          @commands.instance_eval(&block)
        rescue Exception=>e
          raise e
        ensure
          print "[\e[0;32mDONE\e[0m]\n"
        end
      }
    end
  end

  def run(txt, &block)
    @run_blocks << {:txt=>txt, :block=>block}
  end

  def cleanup(&block)
    @cleanup_blocks << block
  end

end