require 'rubygems'
require 'rspec'
require 'provision'
require 'provision/vm/virsh'
require 'provision/core/provisioning_service'
require 'provision/dns'
require 'pp'

module RSpec::Mocks::ArgumentMatchers
  module MachineSpecMatchers
    class HasSpecEntries
      def initialize(expected)
        @expected = expected
      end

      def ==(actual)
        mismatches = []
        @expected.keys.each do |key|
          mismatches << "expected #{key} to be #{@expected[key].inspect} but it was #{actual[key].inspect}" unless actual[key] == @expected[key]
        end
        raise mismatches.join("\n") unless mismatches.empty?
        return true
      end

      def description
        "expecting spec to match #{@expected.inspect}"
      end
    end

    def spec_with(expected)
      return HasSpecEntries.new(expected)
    end
  end
end

RSpec.configure do |config|
  config.include(RSpec::Mocks::ArgumentMatchers::MachineSpecMatchers)
end

describe Provision::Core::ProvisioningService do
  describe "without a storage service" do
    before do
      @image_service = double()
      @vm_service = double()
      @numbering_service = double()
      @provisioning_service = Provision::Core::ProvisioningService.new(
        :image_service => @image_service,
        :vm_service => @vm_service,
        :numbering_service => @numbering_service
      )
      @vm_service.stub(:is_defined).and_return(false)
    end

    it 'reports noaction if the machine already existed' do
      @vm_service.stub(:is_defined).and_return(true)
      @vm_service.stub(:start_vm).and_return(true)

      expect {
        @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise").should eql(false)
      }.to raise_error("failed to launch vmx1 already exists")
    end

    it 'allows the user to define vm from an image catalogue and vmdescription catalogue' do
      @numbering_service.should_receive(:allocate_ips_for)
      @image_service.should_receive(:build_image).with("ubuntuprecise", anything).ordered
      @vm_service.should_receive(:define_vm).ordered
      @vm_service.should_receive(:start_vm).ordered
      @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise").should eql(true)
    end

    it 'allows ips to produce' do
      network_address = {
        "mgmt" => {
          :ip => "192.168.24.5",
          :netmask => "255.255.255.0"
        }
      }
      @numbering_service.stub(:allocate_ips_for).and_return(network_address)

      @image_service.should_receive(:build_image).with("ubuntuprecise", spec_with(:networking => network_address)).ordered
      @vm_service.should_receive(:define_vm).ordered
      @vm_service.should_receive(:start_vm).ordered
      @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise")
    end

    it 'allows the user to clean up vms' do
      @vm_service.should_receive(:is_running)
      @vm_service.should_receive(:undefine_vm).ordered
      @image_service.should_receive(:remove_image)
      @provisioning_service.clean_vm(:hostname => "vmx1", :template => "ubuntuprecise")
    end

    it 'cleanup should call destroy if vm running' do
      @vm_service.stub(:is_running).and_return true
      @vm_service.should_receive(:is_running)
      @vm_service.should_receive(:destroy_vm)
      @image_service.should_receive(:remove_image)
      @vm_service.should_receive(:undefine_vm).ordered
      @provisioning_service.clean_vm(:hostname => "vmx1", :template => "ubuntuprecise")
    end

    it 'allows defaults to be passed to new MachineSpecs' do
      @provisioning_service = Provision::Core::ProvisioningService.new(
        :image_service => @image_service,
        :vm_service => @vm_service,
        :numbering_service => @numbering_service,
        :defaults => {
          :template => "ubuntuprecise",
          :enc => {:classes => {}}
        }
      )
      @numbering_service.should_receive(:allocate_ips_for)
      @image_service.should_receive(:build_image).with("ubuntuprecise", anything).ordered
      @vm_service.should_receive(:define_vm).ordered
      @vm_service.should_receive(:start_vm).ordered
      @provisioning_service.provision_vm(:hostname => "vmx1")
    end

    it 'overrides defaults passed to new MachineSpecs' do
      @provisioning_service = Provision::Core::ProvisioningService.new(
        :image_service => @image_service,
        :vm_service => @vm_service,
        :numbering_service => @numbering_service,
        :defaults => {
          :template => "blah",
          :enc => {:classes => {}}
        }
      )
      @numbering_service.should_receive(:allocate_ips_for)
      @image_service.should_receive(:build_image).with("ubuntuprecise", anything).ordered
      @vm_service.should_receive(:define_vm).ordered
      @vm_service.should_receive(:start_vm).ordered
      @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise")
    end

    it 'will allocate you an IP for a name without doing anything else, like for a VIP' do
      spec = {:networks => ['mtv'], :qualified_hostnames => {'mtv' => 'beavis.mtv.cable.net.local'}}
      networking = {:mtv => {:netmask => "0.0.0.0", :address => "1.2.3.4"}}
      @numbering_service.should_receive(:allocate_ips_for).with(spec_with(spec)).and_return(networking)
      @provisioning_service.allocate_ip(spec)
    end
  end

  describe "with a storage service" do
    before do
      @image_service = double()
      @vm_service = double()
      @numbering_service = double()
      @storage_service = double()
      @provisioning_service = Provision::Core::ProvisioningService.new(
        :image_service => @image_service,
        :vm_service => @vm_service,
        :numbering_service => @numbering_service,
        :storage_service => @storage_service
      )
      @vm_service.stub(:is_defined).and_return(false)
      @storage_service.stub(:spec_to_xml).and_return("some xml")

      @storage_hash = {
        :/ => {
          :type => 'os',
          :size => '10G',
        }
      }
    end

    it 'reports noaction if the machine already existed' do
      @vm_service.stub(:is_defined).and_return(true)
      @vm_service.stub(:start_vm).and_return(true)

      expect {
        @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise", :storage => @storage_hash).should eql(false)
      }.to raise_error("failed to launch vmx1 already exists")
    end

    it 'allows the user to define vm from an image catalogue and vmdescription catalogue' do
      @numbering_service.should_receive(:allocate_ips_for)
      @storage_service.should_receive(:prepare_storage).with("vmx1", @storage_hash, "/tmp/provisioning-tools/build/vmx1").ordered
      @image_service.should_receive(:build_image).with("ubuntuprecise", anything).ordered
      @storage_service.should_receive(:finish_preparing_storage).with("vmx1", @storage_hash, "/tmp/provisioning-tools/build/vmx1").ordered
      @storage_service.should_receive(:spec_to_xml).with("vmx1", @storage_hash).ordered
      @vm_service.should_receive(:define_vm).with(kind_of(Provision::Core::MachineSpec), "some xml").ordered
      @vm_service.should_receive(:start_vm).ordered
      @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise", :storage => @storage_hash).should eql(true)
    end

    it 'allows ips to produce' do
      network_address = {
        "mgmt" => {
          :ip => "192.168.24.5",
          :netmask => "255.255.255.0"
        }
      }
      @numbering_service.stub(:allocate_ips_for).and_return(network_address)

      @storage_service.should_receive(:prepare_storage).with("vmx1", @storage_hash, "/tmp/provisioning-tools/build/vmx1").ordered
      @image_service.should_receive(:build_image).with("ubuntuprecise", anything).ordered
      @storage_service.should_receive(:finish_preparing_storage).with("vmx1", @storage_hash, "/tmp/provisioning-tools/build/vmx1").ordered
      @storage_service.should_receive(:spec_to_xml).with("vmx1", @storage_hash).ordered
      @vm_service.should_receive(:define_vm).ordered
      @vm_service.should_receive(:start_vm).ordered
      @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise", :storage => @storage_hash)
    end

    it 'allows the user to clean up vms' do
      @vm_service.should_receive(:is_running).ordered
      @storage_service.should_receive(:remove_storage).with("vmx1", @storage_hash).ordered
      @vm_service.should_receive(:undefine_vm).ordered
      @provisioning_service.clean_vm(:hostname => "vmx1", :template => "ubuntuprecise", :storage => @storage_hash)
    end

    it 'allows defaults to be passed to new MachineSpecs' do
      @provisioning_service = Provision::Core::ProvisioningService.new(
        :image_service => @image_service,
        :vm_service => @vm_service,
        :numbering_service => @numbering_service,
        :storage_service => @storage_service,
        :defaults => {
          :template => "ubuntuprecise",
          :enc => {:classes => {}}
        }
      )
      @numbering_service.should_receive(:allocate_ips_for)
      @storage_service.should_receive(:prepare_storage).with("vmx1", @storage_hash, "/tmp/provisioning-tools/build/vmx1").ordered
      @image_service.should_receive(:build_image).with("ubuntuprecise", anything).ordered
      @storage_service.should_receive(:finish_preparing_storage).with("vmx1", @storage_hash, "/tmp/provisioning-tools/build/vmx1").ordered
      @storage_service.should_receive(:spec_to_xml).with("vmx1", @storage_hash).ordered
      @vm_service.should_receive(:define_vm).ordered
      @vm_service.should_receive(:start_vm).ordered
      @provisioning_service.provision_vm(:hostname => "vmx1", :storage => @storage_hash)
    end

    it 'overrides defaults passed to new MachineSpecs' do
      @provisioning_service = Provision::Core::ProvisioningService.new(
        :image_service => @image_service,
        :vm_service => @vm_service,
        :numbering_service => @numbering_service,
        :storage_service => @storage_service,
        :defaults => {
          :template => "blah",
          :enc => {:classes => {}}
        }
      )
      @numbering_service.should_receive(:allocate_ips_for)
      @storage_service.should_receive(:prepare_storage).with("vmx1", @storage_hash, "/tmp/provisioning-tools/build/vmx1").ordered
      @image_service.should_receive(:build_image).with("ubuntuprecise", anything).ordered
      @storage_service.should_receive(:finish_preparing_storage).with("vmx1", @storage_hash, "/tmp/provisioning-tools/build/vmx1").ordered
      @storage_service.should_receive(:spec_to_xml).with("vmx1", @storage_hash).ordered
      @vm_service.should_receive(:define_vm).ordered
      @vm_service.should_receive(:start_vm).ordered
      @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise", :storage => @storage_hash)
    end

    it 'will allocate you an IP for a name without doing anything else, like for a VIP' do
      spec = {:networks => ['mtv'], :qualified_hostnames => {'mtv' => 'beavis.mtv.cable.net.local'}}
      networking = {:mtv => {:netmask => "0.0.0.0", :address => "1.2.3.4"}}
      @numbering_service.should_receive(:allocate_ips_for).with(spec_with(spec)).and_return(networking)
      @provisioning_service.allocate_ip(spec)
    end
  end
end
