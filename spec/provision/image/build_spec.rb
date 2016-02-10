require 'provisioning-tools/provision/core/machine_spec'

class XYZ
end

describe XYZ do
  before do
    @commands = double
    MockFunctions.commands = @commands
  end

  module MockFunctions
    def self.commands=(commands)
      @@commands = commands
    end

    def action(args = nil)
      @@commands.action(args)
    end

    def die(args)
      fail "I was asked to die: #{args}"
    end

    def returns_something
      "something"
    end

    def blah
    end
  end

  it 'has access to the config object' do
    require 'provisioning-tools/provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") do
        action(config[:item])
      end
      cleanup do
        action(config[:item2])
      end
    end

    build = Provision::Image::Catalogue.build("vanillavm", Provision::Core::MachineSpec.
      new(:hostname => "myfirstmachine"), :item => "run", :item2 => "clean")

    @commands.should_receive(:action).with("run")
    @commands.should_receive(:action).with("clean")

    build.execute
  end

  it 'cleanup blocks run after run blocks' do
    require 'provisioning-tools/provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") do
        action("1")
        action("2")
        action("3")
      end
      cleanup do
        action("6")
        action("7")
      end
      run("do more stuff") do
        action("4")
        action("5")
      end
    end

    build = Provision::Image::Catalogue.build("vanillavm", Provision::Core::MachineSpec.
      new(:hostname => "myfirstmachine"), {})

    @commands.should_receive(:action).with("1")
    @commands.should_receive(:action).with("2")
    @commands.should_receive(:action).with("3")
    @commands.should_receive(:action).with("4")
    @commands.should_receive(:action).with("5")
    @commands.should_receive(:action).with("6")
    @commands.should_receive(:action).with("7")

    build.execute
  end

  it 'cleanup blocks run in reverse order' do
    require 'provisioning-tools/provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      cleanup do
        action("2")
        action("1")
      end
      cleanup do
        action("4")
        action("3")
      end
      cleanup do
        action("6")
        action("5")
      end
    end

    build = Provision::Image::Catalogue.build("vanillavm", Provision::Core::MachineSpec.
      new(:hostname => "myfirstmachine"), {})

    @commands.should_receive(:action).with("6").ordered
    @commands.should_receive(:action).with("5").ordered
    @commands.should_receive(:action).with("4").ordered
    @commands.should_receive(:action).with("3").ordered
    @commands.should_receive(:action).with("2").ordered
    @commands.should_receive(:action).with("1").ordered

    build.execute
  end

  it 'cleanup blocks ignore exceptions' do
    require 'provisioning-tools/provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      cleanup do
        die("6")
        action("5")
      end
    end

    build = Provision::Image::Catalogue.build("vanillavm", Provision::Core::MachineSpec.
      new(:hostname => "myfirstmachine"), {})
    @commands.should_receive(:action).with("5")
    build.execute
  end

  it 'can ignore exceptions if chosen to' do
    require 'provisioning-tools/provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") do
        suppress_error.die("6")
        action("5")
      end
    end

    build = Provision::Image::Catalogue.build("vanillavm", Provision::Core::MachineSpec.
      new(:hostname => "myfirstmachine"), {})
    @commands.should_receive(:action).with("5")
    build.execute
  end

  it 'stops executing run commands after a failure' do
    require 'provisioning-tools/provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("do stuff") do
        action("1")
        die("2")
        action("3")
      end
    end
    build = Provision::Image::Catalogue.build("vanillavm", Provision::Core::MachineSpec.
      new(:hostname => "myfirstmachine"), {})
    @commands.should_receive(:action).with("1")
    @commands.should_not_receive(:action).with("3")

    lambda { build.execute }.should raise_error
  end

  it 'I can pass options through to my build' do
    require 'provisioning-tools/provision/image/catalogue'
    define "vanillavm" do
      extend MockFunctions
      run("configure hostname") do
        hostname = spec[:hostname]
        action(hostname)
      end
    end

    build = Provision::Image::Catalogue.build("vanillavm", Provision::Core::MachineSpec.
      new(:hostname => "myfirstmachine"), {})

    @commands.should_receive(:action).with("myfirstmachine")

    build.execute
  end

  it 'I can provide defaults' do
    require 'provisioning-tools/provision/image/catalogue'
    define "defaults" do
      run("configure defaults") do
        spec[:disksize] = '3G'
      end
    end
    define "vanillavm" do
      extend MockFunctions
      defaults

      run("configure disk") do
        disksize = spec[:disksize]
        action(disksize)
      end
    end

    build = Provision::Image::Catalogue.build("vanillavm", Provision::Core::MachineSpec.new({}), {})
    @commands.should_receive(:action).with("3G")
    build.execute
  end

  it 'can load files from a specified directory' do
    Provision::Image::Catalogue.loadconfig('home/image_builders')
  end

  it 'fails with a good error message' do
    require 'provisioning-tools/provision/image/catalogue'
    define "defaults" do
      run("configure defaults") do
        bing
      end
    end

    build = Provision::Image::Catalogue.build("defaults", {}, {})
    expect do
      build.execute
    end.to raise_error NameError
  end

  it 'passes through the result when using suppress_error' do
    require 'provisioning-tools/provision/image/catalogue'
    something = nil
    define "defaults" do
      extend MockFunctions
      run("configure defaults") do
        something = suppress_error.returns_something
      end
    end

    build = Provision::Image::Catalogue.build("defaults", Provision::Core::MachineSpec.new({}), {})
    build.execute

    something.should eql("something")
  end

  it 'CCCCCc' do
    require 'provisioning-tools/provision/image/catalogue'
    something = nil
    define "defaults" do
      extend Provision::Image::Commands
      extend MockFunctions
      run("configure defaults") do
      end
      cleanup do
        keep_doing do
          suppress_error.die("this line should throw an error and be swallowed")
          something = returns_something
          print "something = #{something} \n"
        end.until { something == "something" }
      end
    end

    build = Provision::Image::Catalogue.build("defaults", Provision::Core::MachineSpec.new({}), {})
    build.execute

    something.should eql("something")
  end

  it 'does not execute a clean up block when no errors occur' do
    require 'provisioning-tools/provision/image/catalogue'
    something = nil
    define "defaults" do
      extend Provision::Image::Commands
      extend MockFunctions
      run("configure defaults") do
      end
      on_error do
        something = "I was executed"
      end
    end

    build = Provision::Image::Catalogue.build("defaults", Provision::Core::MachineSpec.new({}), {})
    build.execute

    something.should be_nil
  end
  it 'execute a clean up block on error' do
    require 'provisioning-tools/provision/image/catalogue'
    something = nil
    define "defaults" do
      extend Provision::Image::Commands
      extend MockFunctions
      run("configure defaults") do
        fail "an error"
      end
      on_error do
        something = "I was executed"
      end
    end

    build = Provision::Image::Catalogue.build("defaults", Provision::Core::MachineSpec.new({}), {})

    expect do
      build.execute
    end.to raise_error "an error"

    something.should eql("I was executed")
  end

  it 'raises a meaningful error when a non-existent template is defined' do
    require 'provisioning-tools/provision/image/catalogue'
    expect do
      Provision::Image::Catalogue.build("noexist", Provision::Core::MachineSpec.new({}), {})
    end.to raise_error("attempt to execute a template that is not in the catalogue: noexist")
  end
end
