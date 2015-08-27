require 'provisioning-tools/provision'
require 'provisioning-tools/provision/storage'
require 'provisioning-tools/provision/storage/lvm'

describe Provision::Storage::LVM do
  before do
    @storage_type = Provision::Storage::LVM.new(:vg => 'main')
    @mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '10G')
    @large_mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5000G')
    @lvm_in_lvm_mount_point_obj = \
      Provision::Storage::MountPoint.new('/mnt/data',
                                         :size => '5G',
                                         :prepare => {
                                           :options => {
                                             :create_guest_lvm => true,
                                             :guest_lvm_pv_size => '10G'
                                           }
                                         })
    @lvm_in_lvm_mount_point_obj.set(:actual_mount_point, '/mnt/somewhere/mnt/data')
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
    expect do
      @storage_type.create('existing', @mount_point_obj)
    end.to raise_error("LV existing already exists in VG main")
  end

  it 'complains if something bad happens trying to create storage' do
    @storage_type.stub(:cmd) do |arg|
      case arg
      when 'lvcreate -L 5000G -n working main'
        fail "command lvcreate -n existing -L 5000G main returned non-zero error code 5"
      end
    end
    expect do
      @storage_type.create('working', @large_mount_point_obj)
    end.to raise_error("command lvcreate -n existing -L 5000G main returned non-zero error code 5")
  end

  it 'runs lvremove when trying to remove a VMs storage' do
    File.stub(:exists?).and_return(true, false)
    mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql', :size => '1M')
    @storage_type.stub(:cmd) do |_arg|
      true
    end

    @storage_type.should_receive(:cmd).with('lvremove -f /dev/main/oy-deletedb-001_var_lib_mysql')
    @storage_type.remove('oy-deletedb-001', mount_point_obj)
  end

  it 'runs lvremove over and over when trying to remove a VMs storage if removing the storage fails' do
    File.stub(:exists?).and_return(true)
    mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql', :size => '1M')
    @storage_type.stub(:cmd) do |_arg|
      fail "fake exception"
    end

    @storage_type.should_receive(:cmd).with('lvremove -f /dev/main/oy-deletedb-001_var_lib_mysql')
    expect do
      @storage_type.remove('oy-deletedb-001', mount_point_obj)
    end.to raise_error("fake exception")
  end

  it 'runs lvremove 100 times if removing the storage fails every time' do
    File.stub(:exists?).and_return(true)
    mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql', :size => '1M')
    @storage_type.stub(:cmd).and_return(true)

    100.times do
      @storage_type.should_receive(:cmd).with('lvremove -f /dev/main/oy-deletedb-001_var_lib_mysql')
    end
    expect do
      @storage_type.remove('oy-deletedb-001', mount_point_obj)
    end.to raise_error("Tried to lvremove but failed 100 times and didn't raise an exception!?")
  end

  describe 'lvm within lvm' do
    it 'runs the correct commands to create guest lvm within a hosts lv' do
      File.stub(:exists?).and_return(false)
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'lvcreate -L 10G -n oy-lvminlvm-001_mnt_data main',
             'parted -s /dev/main/oy-lvminlvm-001_mnt_data mklabel msdos',
             'parted -s /dev/main/oy-lvminlvm-001_mnt_data mkpart primary ext2 2048s 100%',
             'parted -s /dev/main/oy-lvminlvm-001_mnt_data set 1 lvm on',
             'udevadm settle',
             'kpartx -av /dev/main/oy-lvminlvm-001_mnt_data',
             'pvcreate /dev/mapper/main-oy--lvminlvm--001_mnt_data1',
             'vgcreate oy-lvminlvm-001_mnt_data /dev/mapper/main-oy--lvminlvm--001_mnt_data1',
             'lvcreate -L 5G -n _mnt_data oy-lvminlvm-001_mnt_data'
          true
        when 'kpartx -l /dev/main/oy-lvminlvm-001_mnt_data'
          "main-oy--lvminlvm--001_mnt_data1 : 0 20969472 /dev/main/oy-lvminlvm-001_mnt_data 2048"
        else
          fail arg
        end
      end

      @storage_type.should_receive(:cmd).with('lvcreate -L 10G -n oy-lvminlvm-001_mnt_data main').ordered
      @storage_type.should_receive(:cmd).with('parted -s /dev/main/oy-lvminlvm-001_mnt_data mklabel msdos').ordered
      @storage_type.should_receive(:cmd).with('parted -s /dev/main/oy-lvminlvm-001_mnt_data mkpart primary ext2 2048s 100%').ordered
      @storage_type.should_receive(:cmd).with('parted -s /dev/main/oy-lvminlvm-001_mnt_data set 1 lvm on').ordered
      @storage_type.should_receive(:cmd).with('udevadm settle').ordered
      @storage_type.should_receive(:cmd).with('kpartx -av /dev/main/oy-lvminlvm-001_mnt_data').ordered
      @storage_type.should_receive(:cmd).with('udevadm settle').ordered
      @storage_type.should_receive(:cmd).with('kpartx -l /dev/main/oy-lvminlvm-001_mnt_data').ordered
      @storage_type.should_receive(:cmd).with('pvcreate /dev/mapper/main-oy--lvminlvm--001_mnt_data1').ordered
      @storage_type.should_receive(:cmd).with('vgcreate oy-lvminlvm-001_mnt_data /dev/mapper/main-oy--lvminlvm--001_mnt_data1').ordered
      @storage_type.should_receive(:cmd).with('lvcreate -L 5G -n _mnt_data oy-lvminlvm-001_mnt_data').ordered

      @storage_type.create('oy-lvminlvm-001', @lvm_in_lvm_mount_point_obj)
    end

    it 'runs the correct commands to remove a guests storage when lvm is configured within lvm' do
      File.stub(:exists?).and_return(true, true, true, true, false)
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'dd if=/dev/zero of=/dev/main/oy-lvminlvm-001_mnt_data bs=512k count=10',
             'lvremove -f /dev/main/oy-lvminlvm-001_mnt_data'
          true
        else
          fail arg
        end
      end

      @storage_type.should_receive(:cmd).with('dd if=/dev/zero of=/dev/main/oy-lvminlvm-001_mnt_data bs=512k count=10').ordered
      @storage_type.should_receive(:cmd).with('lvremove -f /dev/main/oy-lvminlvm-001_mnt_data').ordered
      @storage_type.should_receive(:cmd).with('lvremove -f /dev/main/oy-lvminlvm-001_mnt_data').ordered

      @storage_type.remove('oy-lvminlvm-001', @lvm_in_lvm_mount_point_obj)
    end

    it 'runs the correct commands to initialise a filesystem when lvm is configured within lvm' do
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'mkfs.ext4 /dev/oy-lvminlvm-001_mnt_data/_mnt_data'
          true
        else
          fail arg
        end
      end

      @storage_type.should_receive(:cmd).with('mkfs.ext4 /dev/oy-lvminlvm-001_mnt_data/_mnt_data').ordered

      @storage_type.init_filesystem('oy-lvminlvm-001', @lvm_in_lvm_mount_point_obj)
    end

    it 'runs the correct commands to mount the filesystem when lvm is configured within lvm' do
      File.stub(:exists?).and_return(true)
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'mount /dev/oy-lvminlvm-001_mnt_data/_mnt_data /mnt/somewhere/mnt/data'
          true
        else
          fail("#{arg}")
        end
      end

      @storage_type.should_receive(:cmd).with('mount /dev/oy-lvminlvm-001_mnt_data/_mnt_data /mnt/somewhere/mnt/data').ordered

      @storage_type.mount('oy-lvminlvm-001', @lvm_in_lvm_mount_point_obj)
    end

    it 'runs the correct commands to unmount the filesystem when lvm is configured within lvm' do
      File.stub(:exists?).and_return(true)
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'umount /mnt/somewhere/mnt/data'
          true
        else
          fail("#{arg}")
        end
      end

      @storage_type.should_receive(:cmd).with('umount /mnt/somewhere/mnt/data').ordered

      @storage_type.unmount('oy-lvminlvm-001', @lvm_in_lvm_mount_point_obj)
    end
    #    it 'runs the correct commands to  lvm is configured within lvm' do
    #      File.stub(:exists?).and_return()
    #      @storage_type.stub(:cmd) do |arg|
    #        case arg
    #        when ''
    #          true
    #        else
    #          fail arg
    #        end
    #      end
    #
    #      @storage_type.should_receive(:cmd).with('dd if=/dev/zero of=/dev/main/oy-lvminlvm-001_mnt_data bs=512k count=10').ordered
    #
    #      @storage_type.('oy-lvminlvm-001', @lvm_in_lvm_mount_point_obj)
    #    end
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
        fail "Un-stubbed call to cmd for #{arg}"
      end
    end
    @storage_type.partition_name('magical', @mount_point_obj).should eql "magical"
  end
end
