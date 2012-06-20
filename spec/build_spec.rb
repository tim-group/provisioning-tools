$: << File.join(File.dirname(__FILE__), "..", "../lib")
require 'rubygems'
require 'rspec'

class XYZ
end

describe XYZ do
  before do
    @commands = double()
    MockFunctions.commands=@commands
  end

  module MockFunctions
    def self.commands=(commands)
      @@commands = commands
    end

    def action(args=nil)
      @@commands.action(args)
    end

    def die(args=nil)
      raise "I was asked to die"
    end

  end

  it 'cleanup blocks run after run blocks' do
    require 'provision/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") {
        action("1")
        action("2")
        action("3")
      }
      cleanup {
        action("6")
        action("7")
      }
      run("do more stuff") {
        action("4")
        action("5")
      }
    end

    build = Provision::Catalogue::build("vanillavm", {:hostname=>"myfirstmachine"})

    @commands.should_receive(:action).with("1")
    @commands.should_receive(:action).with("2")
    @commands.should_receive(:action).with("3")
    @commands.should_receive(:action).with("4")
    @commands.should_receive(:action).with("5")
    @commands.should_receive(:action).with("6")
    @commands.should_receive(:action).with("7")

    build.execute()
  end

  it 'cleanup blocks run in reverse order' do
    require 'provision/catalogue'
    define "vanillavm" do
      extend MockFunctions
      cleanup {
        action("2")
        action("1")
      }
      cleanup {
        action("4")
        action("3")
      }
      cleanup {
        action("6")
        action("5")
      }
    end

    build = Provision::Catalogue::build("vanillavm", {:hostname=>"myfirstmachine"})

    @commands.should_receive(:action).with("6").ordered
    @commands.should_receive(:action).with("5").ordered
    @commands.should_receive(:action).with("4").ordered
    @commands.should_receive(:action).with("3").ordered
    @commands.should_receive(:action).with("2").ordered
    @commands.should_receive(:action).with("1").ordered

    build.execute()
  end

  it 'stops executing run commands after a failure' do
    require 'provision/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") {
        action("1")
        die("2")
        action("3")
      }
    end
    build = Provision::Catalogue::build("vanillavm", {:hostname=>"myfirstmachine"})
    @commands.should_receive(:action).with("1")
    @commands.should_not_receive(:action).with("3")

    lambda {  build.execute() }.should raise_error
  end

  it 'I can pass options through to my build' do
    require 'provision/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("configure hostname") {
        hostname = @options[:hostname]
        action(hostname)
      }
    end

    build = Provision::Catalogue::build("vanillavm", {:hostname=>"myfirstmachine"})

    @commands.should_receive(:action).with("myfirstmachine")

    build.execute()
  end

  it 'I can provide defaults' do
    require 'provision/catalogue'
    define "defaults" do
      run("configure defaults") {
        @options[:disksize] = '3G'
      }
    end
    define "vanillavm" do
      extend MockFunctions
      defaults()

      run("configure disk") {
        disksize = @options[:disksize]
        action(disksize)
      }
    end

    build = Provision::Catalogue::build("vanillavm", {})
    @commands.should_receive(:action).with("3G")
    build.execute()
  end

  it 'can load files from a specified directory' do
    Provision::Catalogue::load('lib/config')
  end

end