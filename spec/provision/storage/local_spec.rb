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
        return "dev='#{device(name)}'"
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

    @storage_type = MockStorage.new({:tmpdir => @tmpdir})
  end

  it 'should not resize the filesystem when resize is false' do
    File.open("#{@tmpdir}/resize_false", 'w').write("source file contents")
    @storage_type.stub(:grow_filesystem)
    settings = {
      :size     => '5G',
      :prepare  => {
        :method  => :image,
        :resize  => false,
        :options => {
          :path    => "#{@tmpdir}/resize_false",
        },
      },
    }
    @storage_type.should_not_receive(:grow_filesystem)
    @storage_type.init_filesystem('resize_false', settings)
  end

  it 'should resize the filesystem when resize is true' do
    File.open("#{@tmpdir}/resize_true", 'w').write("source file contents")
    settings = {
      :size     => '5G',
      :prepare  => {
        :method  => :image,
        :resize  => true,
        :options => {
          :path    => "#{@tmpdir}/resize_true",
        },
      },
    }
    @storage_type.should_receive(:grow_filesystem)
    @storage_type.init_filesystem('resize_true', settings)
  end

  it 'initialises the names storage from an image file path' do
    File.open("#{@tmpdir}/source", 'w') { |file|
      file.write("source file contents")
    }
    settings = {
      :size     => '5G',
      :prepare  => {
        :method  => :image,
        :options => {
          :path    => "#{@tmpdir}/source",
        },
      },
    }
    @storage_type.stub(:grow_filesystem)
    @storage_type.should_receive(:grow_filesystem).with('working', '5G', {:path => "#{@tmpdir}/source"})
    @storage_type.init_filesystem('working', settings)
    File.read("#{@tmpdir}/working").should eql 'source file contents'
  end

  it 'complains if initialising the storage fails' do
    @storage_type.stub(:grow_filesystem)
    FileUtils.touch "#{@tmpdir}/empty_gold.img"
    settings = {
      :size     => '5G',
      :prepare  => {
        :method  => :image,
        :options => {
          :path    => "#{@tmpdir}/empty_gold.img",
        },
      },
    }
    @storage_type.stub(:cmd) do |arg|
      case arg
      when "dd if=#{@tmpdir}/empty_gold.img of=#{@tmpdir}/full"
        raise "command dd if=#{@tmpdir}/empty_gold.img of=#{@tmpdir}/full returned a non-zero error code 1"
      when "kpartx -d #{@tmpdir}/full"
        true
      end
      FileUtils.remove_entry_secure "#{@tmpdir}/empty_gold.img"
    end
    expect {
      @storage_type.init_filesystem('full', settings)
    }.to raise_error("command dd if=#{@tmpdir}/empty_gold.img of=#{@tmpdir}/full returned a non-zero error code 1")
  end

    it 'complains if source image file to copy from does not exist' do
    @storage_type.stub(:grow_filesystem)
      settings = {
        :size     => '5G',
        :prepare  => {
          :method  => :image,
          :options => {
            :path    => "#{@tmpdir}/non-existant-source",
          },
        },
      }
      expect {
        @storage_type.init_filesystem('valid_name', settings)
      }.to raise_error("Source image file #{@tmpdir}/non-existant-source does not exist")
    end

  it 'should remove and re-create partition' do
    name = 'rebuild'
    device_name = @storage_type.device(name)
    @storage_type.should_receive(:cmd).with("parted -s #{device_name} rm 1")
    @storage_type.should_receive(:cmd).with("parted -s #{device_name} mkpart primary ext4 2048s 100%")
    @storage_type.rebuild_partition(name, {})
  end

  it 'should cleanup when remove and re-create partition fails' do
    name = 'rebuild'
    device_name = @storage_type.device(name)
    @storage_type.stub(:cmd) do |arg|
      case arg
      when "parted -s #{device_name} mkpart primary ext4 2048s 100%"
        raise "fail"
      end
    end
    @storage_type.should_receive(:cmd).with("parted -s #{device_name} rm 1")
    @storage_type.should_receive(:cmd).with("parted -s #{device_name} mkpart primary ext4 2048s 100%")
    expect { @storage_type.rebuild_partition(name) }.to raise_error
  end

  it 'should check and resize the filesystem' do
    name = 'check_and_resize'
    device_name = @storage_type.device(name)
    @storage_type.stub(:partition_name) do |arg|
      name
    end
    partition_name = @storage_type.partition_name(name)
    @storage_type.stub(:cmd) do |arg|
      true
    end
    @storage_type.should_receive(:cmd).with("kpartx -a #{device_name}")
    @storage_type.should_receive(:cmd).with("e2fsck -f -p /dev/mapper/#{partition_name}")
    @storage_type.should_receive(:cmd).with("resize2fs /dev/mapper/#{partition_name}")
    @storage_type.should_receive(:cmd).with("kpartx -d #{device_name}")
    @storage_type.check_and_resize_filesystem(name)
  end

  it 'should cleanup if check and resize the filesystem fails' do
    name = 'check_and_resize'
    device_name = @storage_type.device(name)
    @storage_type.stub(:partition_name) do |arg|
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
    @storage_type.should_receive(:cmd).with("kpartx -a #{device_name}")
    @storage_type.should_receive(:cmd).with("e2fsck -f -p /dev/mapper/#{partition_name}")
    @storage_type.should_receive(:cmd).with("kpartx -d #{device_name}")
    expect { @storage_type.check_and_resize_filesystem(name) }.to raise_error
  end

  it 'provides the correct parameter to use with the source tag within the libvirt template' do
    @storage_type.libvirt_source("vm1").should eql("dev='#{@tmpdir}/vm1'")
  end

  it 'tries to create the mountpoint when mounting if it is considered temporary' do
    File.exist?("#{@tmpdir}/place").should eql false
    @storage_type.stub(:partition_name) do |arg|
      'name'
    end
    @storage_type.should_receive(:cmd).with("kpartx -a #{@tmpdir}/name")
    @storage_type.should_receive(:cmd).with("mount /dev/mapper/name #{@tmpdir}/place")
    @storage_type.mount('name', "#{@tmpdir}/place", true)
    File.exist?("#{@tmpdir}/place").should eql true
  end

  it 'does not try to create the mountpoint when mounting if it is not considered temporary' do
    @storage_type.should_not_receive(:cmd).with('mkdir /some/place')
    @storage_type.stub(:partition_name) do |arg|
      'mount'
    end
    @storage_type.mount('mount', '/some/place', false)
  end

  it 'libvirt_source should return correct name' do
    device_name = @storage_type.device('magical')
    @storage_type.libvirt_source('magical').should eql "dev='#{device_name}'"
  end

  it 'partition name should return correct name' do
    device_name = @storage_type.device('magical')
    @storage_type.stub(:cmd) do |arg|
      case arg
      when "kpartx -l #{device_name} | awk '{ print $1 }' | head -1"
        "magical"
      else
        raise "Un-stubbed call to cmd for #{arg}"
      end
    end
    @storage_type.partition_name('magical').should eql "magical"
  end

end
