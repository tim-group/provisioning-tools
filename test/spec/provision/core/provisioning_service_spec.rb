require 'rubygems'
require 'rspec'
require 'provision/vm/virsh'
require 'provision/vm/descriptor'
require 'provision/core/provisioning_service'

describe Provision::Core::ProvisioningService do
  before do
    @image_service = double()
    @vm_service = double()
    @provisioning_service = Provision::Core::ProvisioningService.new(
      :image_service=>@image_service,
      :vm_service=>@vm_service
    )
  end

  it 'should run the configure sections to define common conventions' do
    
  end
  
  it 'allows the user to define vm from an image catalogue and vmdescription catalogue' do
    @vm_service.should_receive(:destroy_vm).ordered
    @vm_service.should_receive(:undefine_vm).ordered
    @image_service.should_receive(:build_image).with("ubuntuprecise",anything).ordered
    @vm_service.should_receive(:define_vm).ordered
    @vm_service.should_receive(:start_vm).ordered

    @provisioning_service.provision_vm(:hostname=>"vmx1",:template=>"ubuntuprecise")
  end

end
