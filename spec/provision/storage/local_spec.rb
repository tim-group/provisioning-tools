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

  it 'should symbolize the value of method' do
    File.open("#{@tmpdir}/symbolize_method", 'w').write("source file contents")
    settings = {
      :size     => '5G',
      :prepare  => {
        :method  => 'image',
        :options => {
          :path    => "#{@tmpdir}/symbolize_method",
        },
      },
    }
    @storage_type.stub(:image_filesystem)
    @storage_type.stub(:grow_filesystem)
    @storage_type.should_receive(:image_filesystem)
    @storage_type.init_filesystem('symbolize_method', '/'.to_sym, settings)
  end
  it 'should not resize the filesystem when resize is false' do
    File.open("#{@tmpdir}/resize_false", 'w').write("source file contents")
    settings = {
      :size     => '5G',
      :prepare  => {
        :method  => :image,
        :options => {
          :path    => "#{@tmpdir}/resize_false",
          :resize  => false,
        },
      },
    }
    @storage_type.should_not_receive(:grow_filesystem)
    @storage_type.init_filesystem('resize_false', '/'.to_sym, settings)
  end

  it 'should convert the name into an underscored version' do
    name = 'test-db-001'
    @storage_type.underscore_name(name, '/var/lib/mysql/').should eql 'test-db-001_var_lib_mysql'
    @storage_type.underscore_name(name, '/').should eql 'test-db-001'
  end

  it 'should resize the filesystem when resize is true' do
    File.open("#{@tmpdir}/resize_true", 'w').write("source file contents")
    settings = {
      :size     => '5G',
      :prepare  => {
        :method  => :image,
        :options => {
          :path    => "#{@tmpdir}/resize_true",
          :resize  => true,
        },
      },
    }
    @storage_type.should_receive(:grow_filesystem)
    @storage_type.init_filesystem('resize_true', '/'.to_sym, settings)
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
    @storage_type.should_receive(:grow_filesystem).with('working', '/'.to_sym, '5G', {:path => "#{@tmpdir}/source"})
    @storage_type.init_filesystem('working', '/'.to_sym, settings)
    File.read("#{@tmpdir}/working").should eql 'source file contents'
  end

  it 'should download the gold image if the path is a url' do
    settings = {
      :size     => '5G',
      :prepare  => {
        :method  => :image,
        :options => {
          :path    => "http://someplace/gold.img",
        },
      },
    }
    @storage_type.should_receive(:cmd).with("curl -Ss --fail http://someplace/gold.img | dd of=#{@tmpdir}/interfoo")
    @storage_type.stub(:grow_filesystem)
    @storage_type.stub(:cmd) do |arg|
      case arg
      when "curl -Ss --fail http://someplace/gold.img | dd of=#{@tmpdir}/interfoo"
        true
      when "kpartx -d #{@tmpdir}/interfoo"
        true
      else
        false
      end
    end
    @storage_type.init_filesystem('interfoo', '/'.to_sym, settings)
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
      @storage_type.init_filesystem('full', '/'.to_sym, settings)
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
        @storage_type.init_filesystem('valid_name', '/'.to_sym, settings)
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
    expect { @storage_type.rebuild_partition(name, '/'.to_sym) }.to raise_error
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
    @storage_type.should_receive(:cmd).with("kpartx -av #{device_name}")
    @storage_type.should_receive(:cmd).with("e2fsck -f -p /dev/mapper/#{partition_name}")
    @storage_type.should_receive(:cmd).with("resize2fs /dev/mapper/#{partition_name}")
    @storage_type.should_receive(:cmd).with("kpartx -dv #{device_name}")
    @storage_type.check_and_resize_filesystem(name, '/'.to_sym)
  end

  it 'should cleanup if check and resize the filesystem fails' do
    name = 'check_and_resize'
    underscore_name = @storage_type.underscore_name(name, '/'.to_sym)
    device_name = @storage_type.device(underscore_name)
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
    @storage_type.should_receive(:cmd).with("kpartx -av #{device_name}")
    @storage_type.should_receive(:cmd).with("e2fsck -f -p /dev/mapper/#{partition_name}")
    @storage_type.should_receive(:cmd).with("kpartx -dv #{device_name}")
    expect { @storage_type.check_and_resize_filesystem(name, '/'.to_sym) }.to raise_error
  end

  it 'provides the correct parameter to use with the source tag within the libvirt template' do
    @storage_type.libvirt_source("vm1").should eql("dev='#{@tmpdir}/vm1'")
  end

  it 'tries to create the mountpoint when mounting if it is considered temporary' do
    File.exist?("#{@tmpdir}/place").should eql false
    @storage_type.stub(:partition_name) do |arg|
      'name'
    end
    @storage_type.should_receive(:cmd).with("kpartx -av #{@tmpdir}/name")
    @storage_type.should_receive(:cmd).with("mount /dev/mapper/name #{@tmpdir}/place")
    @storage_type.mount('name', '/'.to_sym, "#{@tmpdir}/place", true)
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
      when "kpartx -l #{device_name} | grep -v 'loop deleted : /dev/loop' | awk '{ print $1 }' | tail -1"
        "magical"
      else
        raise "Un-stubbed call to cmd for #{arg}"
      end
    end
    @storage_type.partition_name('magical').should eql "magical"
  end

end
