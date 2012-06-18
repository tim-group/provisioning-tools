$: << File.join(File.dirname(__FILE__), "..", "../lib")
require 'rubygems'
require 'rspec'
require 'provision/build'

module Provision
  
  def ubuntu
  end
  
  def whatever
  end
  
  require 'blah'

  class Builder
    include Provision
  end
  
end


describe Provision::Build do
  before do
    @commands = double(Provision::Commands)
    @dsl = Provision::DSL.new(:commands=>@commands)
    @build = Provision::Build.new(:dsl=>@dsl)
  end

  it 'allows composition'  do
    @build.interpret_dsl do
      define "ubuntu_precise" do
        run("doing stuff") {
          cmd "precise-start"
        }
        run("doing stuff") {
          cmd "precise-tidyup"
        }
      end

      define "puppet_master" do
        ubuntu_precise()
        run("doing stuff") {
          cmd "puppet-master-start"
        }
        run("doing stuff") {
          cmd "puppet-master-tidyup"
        }
      end

      define "extra" do
        puppet_master()
        run("extra-block") {
          cmd "extra"
        }
      end
    end

    @commands.should_receive(:cmd).with("precise-start").ordered
    @commands.should_receive(:cmd).with("precise-tidyup").ordered
    @commands.should_receive(:cmd).with("puppet-master-start").ordered
    @commands.should_receive(:cmd).with("puppet-master-tidyup").ordered
    @commands.should_receive(:cmd).with("extra").ordered
    @build.provision("extra")
  end

  it 'executes cleanup instructions after run instructions'  do
    @build.interpret_dsl do
      define "template-x" do
        run("command") {
          cmd "hello1"
        }
        cleanup {
          cmd "cleanup1"
        }
        run("command") {
          cmd "hello2"
        }
        cleanup {
          cmd "cleanup2"
        }
      end
    end

    @commands.should_receive(:cmd).with("hello1").ordered
    @commands.should_receive(:cmd).with("hello2").ordered
    @commands.should_receive(:cmd).with("cleanup2").ordered
    @commands.should_receive(:cmd).with("cleanup1").ordered
    @build.provision("template-x")
  end

  it 'stops executing if an error occurs in a previous command' do
    @build.interpret_dsl do
      define "template-x" do
        run("command") {
          cmd "hello"
        }
        cleanup {
          cmd "clean"
        }
        run("command") {
          cmd "hello"
        }
      end

    end

    @commands.stub(:cmd).with(anything).and_raise("BAD STUFF")
    @commands.should_receive(:cmd).with("hello").ordered
    @commands.should_receive(:cmd).with("clean").ordered

    proc { @build.provision("template-x") }.should raise_error(StandardError, "BAD STUFF")
  end
#
#  it 'I can pass a hostname' do
#    @build.interpret_dsl do
#      define "vanillavm" do
#        run("configure hostname") {
#          hostname = options[:hostname]
#          hostname(hostname)
#        }
#      end
#    end
#
#    @commands.should_receive(:hostname,"myoldchina").ordered
#    @build.provision("vanillavm", {
#      :hostname=>"myoldchina"
#    })
#  end

  it 'defines a libvirt xml file'

  it 'has the correct hostname set'

  it 'creates a user that can login'

  it 'is running a puppet master'

  it 'builds a vanilla install without errors'
end