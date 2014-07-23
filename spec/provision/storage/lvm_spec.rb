require 'rspec'
require 'provision'
require 'provision/storage'
require 'provision/storage/lvm'

describe Provision::Storage::LVM do
  before do
    @storage_type = Provision::Storage::LVM.new(:vg => 'main')
  end

  it 'creates some storage given a name and a size' do
    @storage_type.stub(:cmd) do |arg|
      case arg
      when 'lvcreate -n working -L 10G main'
        "  Logical volume \"working\" created"
      end
    end
    @storage_type.create('working', '/'.to_sym, '10G')
  end

  it 'complains if the storage to be created already exists' do
    File.stub(:exists?) do |arg|
      case arg
      when '/dev/main/existing'
        true
      end
    end
    expect {
      @storage_type.create('existing', '/'.to_sym, '10G')
    }.to raise_error("Logical volume existing already exists in volume group main")
  end

  it 'complains if something bad happens trying to create storage' do
    @storage_type.stub(:cmd) do |arg|
      case arg
      when 'lvcreate -n working -L 500G main'
        raise "command lvcreate -n existing -L 500G main returned non-zero error code 5"
      end
    end
    expect {
      @storage_type.create('working', '/'.to_sym, '500G')
    }.to raise_error("command lvcreate -n existing -L 500G main returned non-zero error code 5")
  end

  it 'runs lvremove when trying to remove a VMs storage' do
    @storage_type.stub(:cmd) do |arg|
      true
    end
    @storage_type.should_receive(:cmd).with('lvremove -f /dev/main/delete')
    @storage_type.remove('delete')
  end

  describe 'grow' do

    it 'runs the commands required to grow a filesystem' do
      name = 'grow_ok'
      device_name = @storage_type.device(name)
      @storage_type.stub(:partition_name) do |arg|
        name
      end
      @storage_type.stub(:cmd) do |arg|
        true
      end
      @storage_type.should_receive(:rebuild_partition).with(name, '/'.to_sym, {})
      @storage_type.should_receive(:check_and_resize_filesystem).with(name, '/'.to_sym)
      @storage_type.grow_filesystem(name, '/'.to_sym, '5G')
    end
  end

end
