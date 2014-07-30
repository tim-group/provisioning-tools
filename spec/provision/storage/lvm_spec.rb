require 'rspec'
require 'provision'
require 'provision/storage'
require 'provision/storage/lvm'

describe Provision::Storage::LVM do
  before do
    @storage_type = Provision::Storage::LVM.new(:vg => 'main')
    @mount_point_obj = Provision::Storage::Mount_point.new('/', {:size => '10G'})
    @large_mount_point_obj = Provision::Storage::Mount_point.new('/', {:size => '5000G'})
  end

  it 'creates some storage given a name and a size' do
    @storage_type.stub(:cmd) do |arg|
      case arg
      when 'lvcreate -n working -L 10G main'
        "  Logical volume \"working\" created"
      end
    end
    @storage_type.create('working', @mount_point_obj)
  end

  it 'complains if the storage to be created already exists' do
    File.stub(:exists?) do |arg|
      case arg
      when '/dev/main/existing'
        true
      end
    end
    expect {
      @storage_type.create('existing', @mount_point_obj)
    }.to raise_error("Logical volume existing already exists in volume group main")
  end

  it 'complains if something bad happens trying to create storage' do
    @storage_type.stub(:cmd) do |arg|
      case arg
      when 'lvcreate -n working -L 5000G main'
        raise "command lvcreate -n existing -L 5000G main returned non-zero error code 5"
      end
    end
    expect {
      @storage_type.create('working', @large_mount_point_obj)
    }.to raise_error("command lvcreate -n existing -L 5000G main returned non-zero error code 5")
  end

  it 'runs lvremove when trying to remove a VMs storage' do
    File.stub(:exists?) do |arg|
      case arg
      when '/dev/main/oy-deletedb-001_var_lib_mysql'
        true
      end
    end
    @storage_type.stub(:cmd) do |arg|
      true
    end
    @storage_type.should_receive(:cmd).with('lvremove -f /dev/main/oy-deletedb-001_var_lib_mysql')
    @storage_type.remove('oy-deletedb-001', '/var/lib/mysql')
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
      @storage_type.should_receive(:rebuild_partition).with(name, @mount_point_obj)
      @storage_type.should_receive(:check_and_resize_filesystem).with(name, @mount_point_obj)
      @storage_type.grow_filesystem(name, @mount_point_obj)
    end
  end

  it 'partition name should return correct name' do
    device_name = @storage_type.device('magical')
    @storage_type.stub(:cmd) do |arg|
      case arg
      when "kpartx -l #{device_name} | grep -v 'loop deleted : /dev/loop' | awk '{ print $1 }' | tail -1"
        "magical"
      else
        raise "Un-stubbed call to cmd for #{arg}"
      end
    end
    @storage_type.partition_name('magical', @mount_point_obj).should eql "magical"
  end

end