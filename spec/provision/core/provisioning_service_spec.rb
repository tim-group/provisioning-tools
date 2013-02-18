require 'rubygems'
require 'rspec'
require 'provision'
require 'provision/vm/virsh'
require 'provision/core/provisioning_service'
require 'provision/dns'
require 'pp'

module RSpec::Mocks::ArgumentMatchers
  module MachineSpecMatchers
    class HasNetworkConfig
      def initialize(expected)
        @expected = expected
      end

      def ==(actual)
        return true if actual[:networking] == @expected
        raise "expecting networking :#{PP.pp(actual.spec[:networking], "")} to match #{PP.pp(@expected, "")}"
      end

      def description
        "expecting networking to match #{@expected}"
      end
    end

    def network_config(expected)
      return HasNetworkConfig.new(expected)
    end
  end
end

RSpec.configure do |config|
  config.include(RSpec::Mocks::ArgumentMatchers::MachineSpecMatchers)
end

describe Provision::Core::ProvisioningService do
  before do
    @image_service = double()
    @vm_service = double()
    @numbering_service = double()
    @provisioning_service = Provision::Core::ProvisioningService.new(
      :image_service => @image_service,
      :vm_service => @vm_service,
      :numbering_service => @numbering_service
    )
  end

  it 'should run the configure sections to define common conventions' do
  end

  it 'allows the user to define vm from an image catalogue and vmdescription catalogue' do
    @numbering_service.should_receive(:allocate_ips_for)
    @provisioning_service.should_receive(:clean_vm).with(:hostname => "vmx1", :template => "ubuntuprecise", :enc => {:classes => {}})
    @image_service.should_receive(:build_image).with("ubuntuprecise", anything).ordered
    @vm_service.should_receive(:define_vm).ordered
    @vm_service.should_receive(:start_vm).ordered
    @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise")
  end

  it 'allows ips to produce' do
    network_address = {
      "mgmt" => {
        :ip => "192.168.24.5",
        :netmask => "255.255.255.0"
      }
    }
    @numbering_service.stub(:allocate_ips_for).and_return(network_address)

    @provisioning_service.should_receive(:clean_vm).with(:hostname => "vmx1", :template => "ubuntuprecise", :enc => {:classes => {}})

    @image_service.should_receive(:build_image).with("ubuntuprecise", network_config(network_address)).ordered
    @vm_service.should_receive(:define_vm).ordered
    @vm_service.should_receive(:start_vm).ordered
    @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise")
  end

  it 'allows the user to clean up vms' do
    @numbering_service.should_receive(:remove_ips_for)
    @vm_service.should_receive(:destroy_vm).ordered
    @vm_service.should_receive(:undefine_vm).ordered
    @image_service.should_receive(:remove_image)
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
    @provisioning_service.should_receive(:clean_vm).with(:hostname => "vmx1", :template => "ubuntuprecise", :enc => {:classes => {}})
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
    @provisioning_service.should_receive(:clean_vm).with(:hostname => "vmx1", :template => "ubuntuprecise", :enc => {:classes => {}})
    @image_service.should_receive(:build_image).with("ubuntuprecise", anything).ordered
    @vm_service.should_receive(:define_vm).ordered
    @vm_service.should_receive(:start_vm).ordered
    @provisioning_service.provision_vm(:hostname => "vmx1", :template => "ubuntuprecise")
  end
end
