$: << File.join(File.dirname(__FILE__), "..", "../lib")
require 'rubygems'
require 'rspec'
require 'provision/workqueue'

describe Provision::WorkQueue do

  it 'processes work items' do
    @provisioning_service = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service,:worker_count=>1)
    spec = {:hostname => "myvm1",
      :ram => "256Mb"}

    @provisioning_service.should_receive(:provision_vm).with(spec)
    @workqueue.add(spec)
    @workqueue.process()
  end

  it 'processes a number of work items between threads' do
    @provisioning_service = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service,:worker_count=>1)
    10.times { |i|
      spec = {:hostname => "myvm_#{i}",
        :ram => "256Mb"}
      @workqueue.add(spec)
      @provisioning_service.should_receive(:provision_vm).with(spec)
    }
    @workqueue.process()
  end

  it 'allows a class to listen to what is going on' do
    @provisioning_service = double()
    @listener = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service,
    :worker_count=>1,
    :listener=>@listener)
    @listener.should_receive(:update).with({:completed=>0,:errors=>0})

    10.times { |i|
      spec = {:hostname => "myvm_#{i}",
        :ram => "256Mb"}
      @workqueue.add(spec)
      completed = i+1
      @provisioning_service.should_receive(:provision_vm)
      @listener.should_receive(:update).with({:completed=>completed,:errors=>0})
    }

    @workqueue.process()
  end
end
