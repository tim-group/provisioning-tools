$: << File.join(File.dirname(__FILE__), "..", "../lib")
require 'rubygems'
require 'rspec'
require 'provision/workqueue'

describe Provision::WorkQueue do
  before do
    @listener = NoopListener.new()
  end

  it 'processes many launch requests' do
    mock_virsh = double()
    @provisioning_service = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service,:worker_count=>1, :listener=>@listener, :virsh=>mock_virsh)
    spec = {:hostname => "myvm1", :thread_number=>1}
    @provisioning_service.should_receive(:provision_vm).with(spec)
    @workqueue.launch_all([spec])
  end

  it 'processes many clean requests' do
    mock_virsh = double()
    mock_virsh.stub(:is_defined).and_return(true)
    @provisioning_service = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service,:worker_count=>1, :listener=>@listener, :virsh=>mock_virsh)
    spec = {:hostname => "myvm1", :thread_number=>1}
    @provisioning_service.should_receive(:clean_vm).with(spec)
    @workqueue.destroy_all([spec])
  end

  it 'processes many allocate IP requests' do
    mock_virsh = double()
    @provisioning_service = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service,:worker_count=>1, :listener=>@listener, :virsh=>mock_virsh)
    spec = {:hostname => "myvm1", :thread_number=>1}
    @provisioning_service.should_receive(:allocate_ip).with(spec)
    @workqueue.allocate_ip_all([spec])
  end

  it 'processes work items' do
    @provisioning_service = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service,:worker_count=>1, :listener=>@listener)

    spec = {:hostname => "myvm1",
      :ram => "256Mb"}

    @provisioning_service.should_receive(:provision_vm).with(spec)
    @workqueue.launch(spec)
    @workqueue.process()
  end

  it 'processes a number of work items between threads' do
    @provisioning_service = double()
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service,:worker_count=>1, :listener=>@listener)
    10.times { |i|
      spec = {:hostname => "myvm_#{i}", :ram => "256Mb"}
      @workqueue.launch(spec)
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

    10.times { |i|
      spec = {:hostname => "myvm_#{i}",
        :ram => "256Mb"}
      @workqueue.launch(spec)
      completed = i+1
      @provisioning_service.should_receive(:provision_vm)
      @listener.should_receive(:passed)
    }

    @workqueue.process()
  end

  it 'cleans up vms' do
    @provisioning_service = double()
    mock_virsh = double()
    mock_virsh.stub(:is_defined).and_return(true)
    @workqueue = Provision::WorkQueue.new(:provisioning_service=>@provisioning_service,:worker_count=>1, :listener=>@listener, :virsh => mock_virsh)
    spec = {:hostname => "myvm1", :ram => "256Mb"}
    @provisioning_service.should_receive(:clean_vm).with(spec)
    @workqueue.destroy(spec)
    @workqueue.process()
  end

  it 'cleans only vms this compute node houses' do
    @provisioning_service = double()
    mock_virsh = double()
    @workqueue = Provision::WorkQueue.new(
                    :provisioning_service=>@provisioning_service,
                    :worker_count=>1,
                    :listener=>@listener,
                    :virsh=> mock_virsh)

    spec = {:hostname => "myvm1", :thread_number => 0}
    spec2 = {:hostname => "myvm2", :thread_number => 0}
    mock_virsh.stub(:is_defined).with(spec).and_return(true)
    mock_virsh.stub(:is_defined).with(spec2).and_return(false)

    @provisioning_service.should_receive(:clean_vm)
    @workqueue.destroy(spec)
    @workqueue.destroy(spec2)
    @workqueue.process()

    @listener.results.should eql({"myvm1"=> "success"})
  end

end
