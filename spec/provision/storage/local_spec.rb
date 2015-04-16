require 'spec_helper'
require 'rspec'
require 'provision'
require 'provision/storage'
require 'provision/storage/local'

describe Provision::Storage::Local do
  class MockStorage < Provision::Storage
    include Provision::Storage::Local
    def initialize(options)
      @tmpdir = options[:tmpdir]
      super(options)
    end

    def device(name)
      "#{@tmpdir}/#{name}"
    end

    def libvirt_source(name)
      "dev='#{device(name)}'"
    end

    def remove(name)
      true
    end
  end

  after do
    FileUtils.remove_entry_secure @tmpdir
  end

  before do
    @tmpdir = Dir.mktmpdir
    File.stub(:exists?) do |arg|
      case arg
      when '/dev/main/working'
        false
      when '/some/non/existing/place'
        false
      when '/dev/main/existing'
        true
      end
    end

    @storage_type = MockStorage.new(:tmpdir => @tmpdir)
    @mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '10G')
  end

  it 'should symbolize the value of method' do
    File.open("#{@tmpdir}/symbolize_method", 'w').write("source file contents")
    mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5G',
                                                                :prepare => {
                                                                  :method => 'image',
                                                                  :options => {
                                                                    :path => "#{@tmpdir}/symbolize_method"
                                                                  }
                                                                })
    @storage_type.stub(:image_filesystem)
    @storage_type.stub(:grow_filesystem)
    @storage_type.should_receive(:image_filesystem)
    @storage_type.init_filesystem('symbolize_method', mount_point_obj)
  end
  it 'should not resize the filesystem when resize is false' do
    File.open("#{@tmpdir}/resize_false", 'w').write("source file contents")
    mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5G',
                                                                :prepare => {
                                                                  :method => :image,
                                                                  :options => {
                                                                    :path   => "#{@tmpdir}/resize_false",
                                                                    :resize => false
                                                                  }
                                                                })
    @storage_type.should_not_receive(:grow_filesystem)
    @storage_type.init_filesystem('resize_false', mount_point_obj)
  end

  it 'should convert the name into an underscored version' do
    name = 'test-db-001'
    @storage_type.underscore_name(name, '/var/lib/mysql/').should eql 'test-db-001_var_lib_mysql'
    @storage_type.underscore_name(name, '/').should eql 'test-db-001'
  end

  it 'should resize the filesystem when resize is true' do
    File.open("#{@tmpdir}/resize_true", 'w').write("source file contents")
    mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5G',
                                                                :prepare => {
                                                                  :method => :image,
                                                                  :options => {
                                                                    :path   => "#{@tmpdir}/resize_true",
                                                                    :resize => true
                                                                  }
                                                                })
    @storage_type.should_receive(:grow_filesystem)
    @storage_type.init_filesystem('resize_true', mount_point_obj)
  end

  it 'initialises the names storage from an image file path' do
    File.open("#{@tmpdir}/source", 'w') do |file|
      file.write("source file contents")
    end

    mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5G',
                                                                :prepare => {
                                                                  :method => :image,
                                                                  :options => {
                                                                    :path => "#{@tmpdir}/source"
                                                                  }
                                                                })
    @storage_type.stub(:grow_filesystem)
    @storage_type.should_receive(:grow_filesystem).with('working', mount_point_obj)
    @storage_type.init_filesystem('working', mount_point_obj)
    File.read("#{@tmpdir}/working").should eql 'source file contents'
  end

  it 'should download the gold image if the path is a url' do
    mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5G',
                                                                :prepare => {
                                                                  :method => :image,
                                                                  :options => {
                                                                    :path => "http://someplace/gold.img"
                                                                  }
                                                                })
    @storage_type.should_receive(:cmd).with("curl -Ss --fail http://someplace/gold.img | dd bs=1M of=#{@tmpdir}/interfoo")
    @storage_type.stub(:grow_filesystem)
    @storage_type.stub(:cmd) do |arg|
      case arg
      when "curl -Ss --fail http://someplace/gold.img | dd bs=1M of=#{@tmpdir}/interfoo"
        true
      when "kpartx -d #{@tmpdir}/interfoo"
        true
      else
        false
      end
    end
    @storage_type.init_filesystem('interfoo', mount_point_obj)
  end

  it 'complains if initialising the storage fails' do
    @storage_type.stub(:grow_filesystem)
    FileUtils.touch "#{@tmpdir}/empty_gold.img"
    mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5G',
                                                                :prepare => {
                                                                  :method => :image,
                                                                  :options => {
                                                                    :path => "#{@tmpdir}/empty_gold.img"
                                                                  }
                                                                })
    @storage_type.stub(:cmd) do |arg|
      case arg
      when "dd bs=1M if=#{@tmpdir}/empty_gold.img of=#{@tmpdir}/full"
        raise "command dd bs=1M if=#{@tmpdir}/empty_gold.img of=#{@tmpdir}/full returned a non-zero error code 1"
      when "kpartx -d #{@tmpdir}/full"
        true
      end
      FileUtils.remove_entry_secure "#{@tmpdir}/empty_gold.img"
    end
    expect do
      @storage_type.init_filesystem('full', mount_point_obj)
    end.to raise_error("command dd bs=1M if=#{@tmpdir}/empty_gold.img of=#{@tmpdir}/full returned a non-zero error code 1")
  end

  it 'complains if source image file to copy from does not exist' do
    @storage_type.stub(:grow_filesystem)
    mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5G',
                                                                :prepare => {
                                                                  :method => :image,
                                                                  :options => {
                                                                    :path => "#{@tmpdir}/non-existant-source"
                                                                  }
                                                                })
    expect do
      @storage_type.init_filesystem('valid_name', mount_point_obj)
    end.to raise_error("Source image file #{@tmpdir}/non-existant-source does not exist")
  end

  it 'should remove and re-create partition' do
    name = 'rebuild'
    device_name = @storage_type.device(name)
    @storage_type.should_receive(:cmd).with("parted -s #{device_name} rm 1")
    @storage_type.should_receive(:cmd).with("parted -s #{device_name} mkpart primary ext4 2048s 100%")
    @storage_type.rebuild_partition(name, @mount_point_obj)
  end

  it 'should cleanup when remove and re-create partition fails' do
    name = 'rebuild'
    underscore_name = @storage_type.underscore_name(name, '/'.to_sym)
    device_name = @storage_type.device(underscore_name)
    @storage_type.stub(:cmd) do |arg|
      case arg
      when "parted -s #{device_name} mkpart primary ext4 2048s 100%"
        raise "fail"
      end
    end
    @storage_type.should_receive(:cmd).with("parted -s #{device_name} rm 1")
    @storage_type.should_receive(:cmd).with("parted -s #{device_name} mkpart primary ext4 2048s 100%")
    expect { @storage_type.rebuild_partition(name, @mount_point_obj) }.to raise_error
  end

  it 'should check and resize the filesystem' do
    name = 'check_and_resize'
    device_name = @storage_type.device(name)
    @storage_type.stub(:partition_name) do |a_name, mount_point_obj|
      name
    end
    partition_name = @storage_type.partition_name(name)
    @storage_type.stub(:cmd) do |arg|
      true
    end
    @storage_type.should_receive(:cmd).with("kpartx -av #{device_name}")
    @storage_type.should_receive(:cmd).with("e2fsck -f -p /dev/mapper/#{partition_name}")
    @storage_type.should_receive(:cmd).with("resize2fs /dev/mapper/#{partition_name}")
    @storage_type.should_receive(:cmd).with("kpartx -dv #{device_name}")
    @storage_type.check_and_resize_filesystem(name, @mount_point_obj)
  end

  it 'should cleanup if check and resize the filesystem fails' do
    name = 'check_and_resize'
    underscore_name = @storage_type.underscore_name(name, '/'.to_sym)
    device_name = @storage_type.device(underscore_name)
    @storage_type.stub(:partition_name) do |a_name, mount_point_obj|
      name
    end
    partition_name = @storage_type.partition_name(name)
    @storage_type.stub(:cmd) do |arg|
      case arg
      when "e2fsck -f -p /dev/mapper/#{partition_name}"
        raise "fail"
      else
        true
      end
    end
    @storage_type.should_receive(:cmd).with("udevadm settle").ordered
    @storage_type.should_receive(:cmd).with("kpartx -av #{device_name}").ordered
    @storage_type.should_receive(:cmd).with("e2fsck -f -p /dev/mapper/#{partition_name}").ordered
    @storage_type.should_receive(:cmd).with("udevadm settle").ordered
    @storage_type.should_receive(:cmd).with("kpartx -dv #{device_name}").ordered
    expect { @storage_type.check_and_resize_filesystem(name, @mount_point_obj) }.to raise_error
    Provision::Storage.cleanup("check_and_resize")
  end

  it 'provides the correct parameter to use with the source tag within the libvirt template' do
    @storage_type.libvirt_source("vm1").should eql("dev='#{@tmpdir}/vm1'")
  end

  it 'tries to create the mountpoint when mounting if it is considered temporary' do
    File.exist?("#{@tmpdir}/place").should eql false
    @storage_type.stub(:partition_name) do |name, mount_point_obj|
      'name'
    end
    @storage_type.should_receive(:cmd).with("udevadm settle")
    @storage_type.should_receive(:cmd).with("kpartx -av #{@tmpdir}/name")
    @storage_type.should_receive(:cmd).with("mount /dev/mapper/name #{@tmpdir}/name")
    @mount_point_obj.set(:actual_mount_point, "#{@tmpdir}/name")
    @mount_point_obj.set(:temp_mount_point, true)
    @storage_type.mount('name', @mount_point_obj)
    File.exist?("#{@tmpdir}/name").should eql true
  end

  it 'does not try to create the mountpoint when mounting if it is not considered temporary' do
    @storage_type.should_not_receive(:cmd).with('mkdir /some/name1')
    @storage_type.stub(:partition_name) do |name, mount_point_obj|
      'mount'
    end
    @mount_point_obj.set(:actual_mount_point, "/some/name1")
    @storage_type.mount('name1', @mount_point_obj)
  end

  it 'libvirt_source should return correct name' do
    device_name = @storage_type.device('magical')
    @storage_type.libvirt_source('magical').should eql "dev='#{device_name}'"
  end

  describe 'check_persistent_storage' do
    it 'will raise an exception if persistent storage was not found' do
      mount_point_hash = { :size => '10G', :persistent => true }
      mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql'.to_sym, mount_point_hash)
      expect do
        @storage_type.check_persistent_storage('oy-foodb-001', mount_point_obj)
      end.to raise_error("Persistent storage was not found for #{@tmpdir}/oy-foodb-001_var_lib_mysql")
    end

    it 'will create storage if persistent storage was not found' do
      mount_point_hash = {
        :size => '10G',
        :persistent => true,
        :persistence_options => { :on_storage_not_found => :create_new }
      }
      mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql'.to_sym, mount_point_hash)
      @storage_type.should_receive(:create).with("oy-foodb-001", mount_point_obj)
      @storage_type.check_persistent_storage('oy-foodb-001', mount_point_obj)
    end

    it 'will check storage if persistent storage already exists' do
      FileUtils.touch "#{@tmpdir}/oy-foodb-001_var_lib_mysql"
      mount_point_hash = {
        :size => '10G',
        :persistent => true
      }
      mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql'.to_sym, mount_point_hash)
      @storage_type.should_receive(:check_and_resize_filesystem).with("oy-foodb-001", mount_point_obj, false)
      @storage_type.check_persistent_storage('oy-foodb-001', mount_point_obj)
    end
  end

  describe 'copying storage' do
    before do
      File.stub(:exists?) do |arg|
        true
      end
    end

    it 'creates the correct command if provided with valid arguments' do
      mount_point_obj = Provision::Storage::MountPoint.new('/'.to_sym, {})
      @storage_type.stub(:cmd) do |arg|
        arg
      end
      transport = 'dd_from_source,gzip,ssh_cmd,gunzip,dd_of,end_ssh_cmd'
      transport_options = 'ssh_cmd__username:grichards,ssh_cmd__host:grichards-desktop.youdevise.com,dd_of__path:/tmp/something.img'
      @storage_type.copy_to("test", mount_point_obj, transport, transport_options).should eql("dd if=#{@tmpdir}/test | gzip | ssh -o StrictHostKeyChecking=no grichards@grichards-desktop.youdevise.com 'gunzip | dd of=/tmp/something.img'")
    end

    it 'blows up if a required transport option is not set' do
      mount_point_obj = Provision::Storage::MountPoint.new('/'.to_sym, {})
      @storage_type.stub(:cmd) do |arg|
        arg
      end
      transport = 'dd_from_source,gzip,ssh_cmd,gunzip,dd_of,end_ssh_cmd'
      transport_options = 'ssh_cmd__username:grichards,ssh_cmd__host:grichards-desktop.youdevise.com'
      expect do
        @storage_type.copy_to("test", mount_point_obj, transport, transport_options)
      end.to raise_error('transport dd_of requires option path')
    end

    it 'blows up if a transport that expect input is provided no input' do
      mount_point_obj = Provision::Storage::MountPoint.new('/'.to_sym, {})
      transport = 'gzip,ssh_cmd,gunzip,dd_of,end_ssh_cmd'
      transport_options = 'ssh_cmd__username:grichards,ssh_cmd__host:grichards-desktop.youdevise.com'
      expect do
        @storage_type.copy_to("test", mount_point_obj, transport, transport_options)
      end.to raise_error('transport gzip expects input, but previous command start provides no output')
    end

    it 'blows up if a transport that is not expecting input is provided input' do
      mount_point_obj = Provision::Storage::MountPoint.new('/'.to_sym, {})
      transport = 'dd_from_source,dd_from_source'
      transport_options = ''
      expect do
        @storage_type.copy_to("test", mount_point_obj, transport, transport_options)
      end.to raise_error('transport dd_from_source does not expect any input, but previous command dd_from_source provides output')
    end

    it 'blows up if a transport option is provided for a transport that is not used' do
      mount_point_obj = Provision::Storage::MountPoint.new('/'.to_sym, {})
      transport = 'dd_from_source,dd_of'
      transport_options = 'dd_of__path:/some/where,ssh_cmd__username:test'
      expect do
        @storage_type.copy_to("test", mount_point_obj, transport, transport_options)
      end.to raise_error('option: username for unused transport: ssh_cmd provided')
    end

    it 'blows up with a storage not found error if the source storage does not exist' do
      File.stub(:exists?) do |arg|
        false
      end
      @storage_type.stub(:cmd) do |arg|
        arg
      end
      mount_point_obj = Provision::Storage::MountPoint.new('/'.to_sym, {})
      transport = 'dd_from_source,dd_of'
      transport_options = 'dd_of__path:/some/where'
      expect do
        @storage_type.copy_to("test", mount_point_obj, transport, transport_options)
      end.to raise_error(Provision::Storage::StorageNotFoundError, "Source device: #{@tmpdir}/test does not exist")
    end
  end
end
