require 'provision/namespace'
require 'provision/dsl'

class Provision::Build
  def initialize(args={})
    @dsl = args[:dsl] || Provision::DSL.new()
  end

  def load(file)
    config = IO.read(file)
    closure = eval("lambda { #{config} \n}")
    self.interpret_dsl(&closure)
  end

  def interpret_dsl(&block)
    @dsl.instance_eval(&block)  
  end

  def provision(template, options={})
    interpret_dsl {
      @options = options
      template(template) {}
    }
    @dsl.execute(options)
  end

end