require 'provisioning-tools/provision'
require 'provisioning-tools/provision/storage'
require 'provisioning-tools/provision/storage/image'
require 'provisioning-tools/provision/storage/mount_point'
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
    it 'complains if the path option is not provided' do
      expect do
        @storage_type = Provision::Storage::Image.new({})
      end.to raise_error("Image storage requires a path as an option, named path")
    end

    it 'complains if the storage to be created already exists' do
      FileUtils.touch "#{@tmpdir}/existing.img"
      mount_point_obj = Provision::Storage::MountPoint.new('/', {})
      expect do
        @storage_type.create('existing', mount_point_obj)
      end.to raise_error("Image file #{@tmpdir}/existing.img already exists")
    end

    it 'should create an empty file' do
      device_name = "#{@tmpdir}/ok.img"
      mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '1M')
      @storage_type.create('ok', mount_point_obj)
      File.exist?(device_name).should eql true
      File.size(device_name).should eql 1_048_576 # 1M
      FileUtils.remove_entry_secure(device_name)
    end
  end

  describe 'remove' do
    it 'should remove the device' do
      FileUtils.touch "#{@tmpdir}/oy-deletedb-001_var_lib_mysql.img"
      mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql', :size => '1M')
      @storage_type.remove('oy-deletedb-001', mount_point_obj)
      File.exist?("#{@tmpdir}/oy-deletedb-001_var_lib_mysql.img").should eql false
    end
  end

  describe 'grow' do
    it 'runs the commands required to grow a filesystem' do
      name = 'grow_ok'
      device_name = @storage_type.device(name)
      @storage_type.stub(:partition_name) do |_arg|
        name
      end
      @storage_type.stub(:cmd) do |_arg|
        true
      end
      mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5G')
      @storage_type.should_receive(:cmd).with("qemu-img resize #{device_name} 5G")
      @storage_type.should_receive(:rebuild_partition).with(name, mount_point_obj)
      @storage_type.should_receive(:check_and_resize_filesystem).with(name, mount_point_obj)
      @storage_type.grow_filesystem(name, mount_point_obj)
    end
  end

  describe 'diff_against_actual' do
    def make_actual(vm, mnt, size)
      File.open("#{@tmpdir}/#{vm}#{mnt.tr('/', '_').gsub(/_$/, '')}.img", 'w') { |f| f.truncate(size) }
    end

    it 'passes when actual storage matches spec' do
      make_actual('oy-good-001', '/var/lib/mysql', 1024)
      mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql', :size => '1K')
      diffs = @storage_type.diff_against_actual('oy-good-001', [mount_point_obj])

      expect(diffs).to be_empty
    end

    it 'reports difference when actual storage missing' do
      mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql', :size => '2M')
      diffs = @storage_type.diff_against_actual('oy-missing-001', [mount_point_obj])

      expect(diffs).to match_array(["#{@tmpdir}/oy-missing-001_var_lib_mysql.img differs: expected size '2048.0' (KiB), but actual size is '' (KiB)"])
    end

    it 'reports difference when actual storage different' do
      make_actual('oy-different-001', '/var/lib/mysql', 512)
      mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql', :size => '1K')
      diffs = @storage_type.diff_against_actual('oy-different-001', [mount_point_obj])

      expect(diffs).to match_array(["#{@tmpdir}/oy-different-001_var_lib_mysql.img differs: expected size '1.0' (KiB), but actual size is '0.5' (KiB)"])
    end

    it 'reports difference when extra actual storage present' do
      make_actual('oy-extra-001', '/var/lib/mysql', 1024)
      make_actual('oy-extra-001', '/var/lib/poop', 512)
      mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql', :size => '1K')
      diffs = @storage_type.diff_against_actual('oy-extra-001', [mount_point_obj])

      expect(diffs).to match_array(["#{@tmpdir}/oy-extra-001_var_lib_poop.img differs: expected size '' (KiB), but actual size is '0.5' (KiB)"])
    end
  end
end
