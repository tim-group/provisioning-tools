require 'rubygems'
require 'rspec'
require 'provision'
require 'provision/vm/virsh'
require 'provision/core/provisioning_service'
require 'provision/dns'

describe Provision::Core::ProvisioningService do
  before do
    @image_service = double()
    @vm_service = double()
    @provisioning_service = Provision::Core::ProvisioningService.new(
      :image_service => @image_service,
      :vm_service => @vm_service,
      :numbering_service => Provision::DNS.get_backend("Fake")
    )
  end

  it 'should run the configure sections to define common conventions' do

  end

  it 'allows the user to define vm from an image catalogue and vmdescription catalogue' do
    @provisioning_service.should_receive(:clean_vm).with(:hostname=>"vmx1",:template=>"ubuntuprecise")
    @image_service.should_receive(:build_image).with("ubuntuprecise",anything).ordered
    @vm_service.should_receive(:define_vm).ordered
    @vm_service.should_receive(:start_vm).ordered
    @provisioning_service.provision_vm(:hostname=>"vmx1",:template=>"ubuntuprecise")
  end

  it 'allows the user to clean up vms' do
    @vm_service.should_receive(:destroy_vm).ordered
    @vm_service.should_receive(:undefine_vm).ordered
    @provisioning_service.clean_vm(:hostname=>"vmx1",:template=>"ubuntuprecise")
  end
end
