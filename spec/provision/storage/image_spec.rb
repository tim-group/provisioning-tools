require 'rspec'
require 'provision'
require 'provision/storage'
require 'provision/storage/image'
require 'provision/storage/mount_point'
require 'tempfile'

describe Provision::Storage::Image do
  after do
    FileUtils.remove_entry_secure @tmpdir
  end

  before do
    @tmpdir = Dir.mktmpdir
    @storage_type = Provision::Storage::Image.new(:image_path => @tmpdir)
  end

  describe 'create' do
    it 'complains if the storage to be created already exists' do
      expect {
        @storage_type = Provision::Storage::Image.new({})
      }.to raise_error("Image storage requires a path as an option, named path")
    end

    it 'complains if the storage to be created already exists' do
      FileUtils.touch "#{@tmpdir}/existing.img"
      mount_point_obj = Provision::Storage::Mount_point.new('/', {})
      expect {
        @storage_type.create('existing', mount_point_obj)
      }.to raise_error("Image file #{@tmpdir}/existing.img already exists")
    end

    it 'should create an empty file' do
      device_name = "#{@tmpdir}/ok.img"
      mount_point_obj = Provision::Storage::Mount_point.new('/', { :size => '1M' })
      @storage_type.create('ok', mount_point_obj).should eql true
      File.exist?(device_name).should eql true
      File.size(device_name).should eql 1048576 #1M
      FileUtils.remove_entry_secure(device_name)
    end
  end

  describe 'remove' do

    it 'should remove the device' do
      FileUtils.touch "#{@tmpdir}/oy-deletedb-001_var_lib_mysql.img"
      @storage_type.remove('oy-deletedb-001', '/var/lib/mysql')
      File.exist?("#{@tmpdir}/oy-deletedb-001_var_lib_mysql.img").should eql false
    end
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
      mount_point_obj = Provision::Storage::Mount_point.new('/', { :size => '5G' })
      @storage_type.should_receive(:cmd).with("qemu-img resize #{device_name} 5G")
      @storage_type.should_receive(:rebuild_partition).with(name, mount_point_obj)
      @storage_type.should_receive(:check_and_resize_filesystem).with(name, mount_point_obj)
      @storage_type.grow_filesystem(name, mount_point_obj)
    end
  end

  xit 'partition name should return correct name' do
  end
end
