$: << File.join(File.dirname(__FILE__), "..", "../lib")
require 'rubygems'
require 'rspec'
require 'provision/workqueue'

describe Provision::WorkQueue do

  it 'processes work items' do
    @provisioning_service = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service)

    spec = {:hostname => "myvm1",
	    :ram => "256Mb"}

    @provisioning_service.should_receive(:provision_vm).with(spec)
    @workqueue.add(spec)
    @workqueue.process()
  end
  
  it 'processes a number of work items between threads' do
    @provisioning_service = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service)

    10.times { |i|
      spec = {:hostname => "myvm_#{i}",
 		:ram => "256Mb"}
      @workqueue.add(spec)
     }

    @provisioning_service.should_receive(:provision_vm).with(any_args)
    @workqueue.process() 
  end
end
