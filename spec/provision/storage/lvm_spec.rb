require 'provisioning-tools/provision'
require 'provisioning-tools/provision/storage'
require 'provisioning-tools/provision/storage/lvm'

describe Provision::Storage::LVM do
  before do
    @storage_type = Provision::Storage::LVM.new(:vg => 'main')
    @mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '10G')
    @large_mount_point_obj = Provision::Storage::MountPoint.new('/', :size => '5000G')
    @lvm_in_guest_mount_point_obj = \
      Provision::Storage::MountPoint.new('/mnt/data',
                                         :size => '5G',
                                         :prepare => {
                                           :options => {
                                             :create_guest_lvm => true,
                                             :guest_lvm_pv_size => '10G'
                                           }
                                         })
    @lvm_in_guest_mount_point_obj.set(:actual_mount_point, '/mnt/somewhere/mnt/data')
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

  describe 'lvm in guest' do
    it 'runs the correct commands to create guest lvm within a hosts lv' do
      File.stub(:exists?).and_return(false)
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'lvcreate -L 10G -n oy-lvminguest-001_mnt_data main',
             'parted -s /dev/main/oy-lvminguest-001_mnt_data mklabel msdos',
             'parted -s /dev/main/oy-lvminguest-001_mnt_data mkpart primary ext2 2048s 100%',
             'parted -s /dev/main/oy-lvminguest-001_mnt_data set 1 lvm on',
             'udevadm settle',
             'kpartx -av /dev/main/oy-lvminguest-001_mnt_data',
             'pvcreate /dev/mapper/main-oy--lvminguest--001_mnt_data1',
             'vgcreate oy-lvminguest-001_mnt_data /dev/mapper/main-oy--lvminguest--001_mnt_data1',
             'lvcreate -L 5G -n _mnt_data oy-lvminguest-001_mnt_data'
          true
        when 'kpartx -l /dev/main/oy-lvminguest-001_mnt_data'
          "main-oy--lvminguest--001_mnt_data1 : 0 20969472 /dev/main/oy-lvminguest-001_mnt_data 2048"
        else
          fail arg
        end
      end

      @storage_type.should_receive(:cmd).with('lvcreate -L 10G -n oy-lvminguest-001_mnt_data main').ordered
      @storage_type.should_receive(:cmd).with('parted -s /dev/main/oy-lvminguest-001_mnt_data mklabel msdos').ordered
      @storage_type.should_receive(:cmd).with('parted -s /dev/main/oy-lvminguest-001_mnt_data mkpart primary ext2 2048s 100%').ordered
      @storage_type.should_receive(:cmd).with('parted -s /dev/main/oy-lvminguest-001_mnt_data set 1 lvm on').ordered
      @storage_type.should_receive(:cmd).with('udevadm settle').ordered
      @storage_type.should_receive(:cmd).with('kpartx -av /dev/main/oy-lvminguest-001_mnt_data').ordered
      @storage_type.should_receive(:cmd).with('udevadm settle').ordered
      @storage_type.should_receive(:cmd).with('kpartx -l /dev/main/oy-lvminguest-001_mnt_data').ordered
      @storage_type.should_receive(:cmd).with('pvcreate /dev/mapper/main-oy--lvminguest--001_mnt_data1').ordered
      @storage_type.should_receive(:cmd).with('vgcreate oy-lvminguest-001_mnt_data /dev/mapper/main-oy--lvminguest--001_mnt_data1').ordered
      @storage_type.should_receive(:cmd).with('lvcreate -L 5G -n _mnt_data oy-lvminguest-001_mnt_data').ordered

      @storage_type.create('oy-lvminguest-001', @lvm_in_guest_mount_point_obj)
    end

    it 'runs the correct commands to remove a guests storage when lvm in guest is setup' do
      File.stub(:exists?).and_return(true, true, true, true, false)
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'dd if=/dev/zero of=/dev/main/oy-lvminguest-001_mnt_data bs=512k count=10',
             'lvremove -f /dev/main/oy-lvminguest-001_mnt_data'
          true
        else
          fail arg
        end
      end

      @storage_type.should_receive(:cmd).with('dd if=/dev/zero of=/dev/main/oy-lvminguest-001_mnt_data bs=512k count=10').ordered
      @storage_type.should_receive(:cmd).with('lvremove -f /dev/main/oy-lvminguest-001_mnt_data').ordered
      @storage_type.should_receive(:cmd).with('lvremove -f /dev/main/oy-lvminguest-001_mnt_data').ordered

      @storage_type.remove('oy-lvminguest-001', @lvm_in_guest_mount_point_obj)
    end

    it 'runs the correct commands to initialise a filesystem when lvm in guest is configured' do
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'mkfs.ext4 /dev/oy-lvminguest-001_mnt_data/_mnt_data'
          true
        else
          fail arg
        end
      end

      @storage_type.should_receive(:cmd).with('mkfs.ext4 /dev/oy-lvminguest-001_mnt_data/_mnt_data').ordered

      @storage_type.init_filesystem('oy-lvminguest-001', @lvm_in_guest_mount_point_obj)
    end

    it 'runs the correct commands to mount the filesystem when lvm is configured within the guest' do
      File.stub(:exists?).and_return(true)
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'mount /dev/oy-lvminguest-001_mnt_data/_mnt_data /mnt/somewhere/mnt/data'
          true
        else
          fail("#{arg}")
        end
      end

      @storage_type.should_receive(:cmd).with('mount /dev/oy-lvminguest-001_mnt_data/_mnt_data /mnt/somewhere/mnt/data').ordered

      @storage_type.mount('oy-lvminguest-001', @lvm_in_guest_mount_point_obj)
    end

    it 'runs the correct commands to unmount the filesystem when lvm is configured within the guest' do
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

      @storage_type.unmount('oy-lvminguest-001', @lvm_in_guest_mount_point_obj)
    end

    it 'should call the correct commands when calling format_filesystem' do
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'mkfs.ext4 /dev/production-db-001_mnt_data/_mnt_data'
          true
        else
          fail arg
        end
      end
      @storage_type.should_receive(:cmd).with("mkfs.ext4 /dev/production-db-001_mnt_data/_mnt_data")
      @storage_type.format_filesystem('production-db-001', @lvm_in_guest_mount_point_obj)
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

  it 'will create device nodes for lvm in guest if persistent storage is found that should be lvm in guest' do
    mount_point_hash = {
      :size => '10G',
      :prepare => {
        :options => {
          :create_guest_lvm => true,
          :guest_lvm_pv_size => '20G'
        }
      },
      :persistent => true
    }
    File.stub(:exist?).and_return(true)
    @storage_type.stub(:cmd) do |arg|
      case arg
      when 'udevadm settle',
           'kpartx -av /dev/main/oy-foodb-001_var_lib_mysql'
        true
      else
        fail arg
      end
    end
    mount_point_obj = Provision::Storage::MountPoint.new('/var/lib/mysql'.to_sym, mount_point_hash)
    @storage_type.should_receive(:cmd).with('udevadm settle').ordered
    @storage_type.should_receive(:cmd).with('kpartx -av /dev/main/oy-foodb-001_var_lib_mysql').ordered
    @storage_type.check_persistent_storage('oy-foodb-001', mount_point_obj)
  end

  describe 'diff_against_actual' do
    def setup_actual_storage
      actual = File.open(File.join(File.dirname(__FILE__), "expected.lvs")).read
      @storage_type.stub(:cmd) do |arg|
        case arg
        when 'lvs --noheadings --nosuffix --separator , --units k --options lv_name,vg_name,lv_size'
          actual
        else
          fail("#{arg}")
        end
      end
      @storage_type.should_receive(:cmd).with('lvs --noheadings --nosuffix --separator , --units k --options lv_name,vg_name,lv_size', true)
    end

    it 'passes when actual storage matches spec' do
      setup_actual_storage
      diffs = @storage_type.diff_against_actual('oy-good-001', [@mount_point_obj])

      expect(diffs).to be_empty
    end

    it 'reports difference when actual storage missing' do
      setup_actual_storage
      diffs = @storage_type.diff_against_actual('oy-missing-001', [@mount_point_obj])

      expect(diffs).to match_array(["oy-missing-001 differs: expected size '10485760.0' (KiB), but actual size is '' (KiB)"])
    end

    it 'reports difference when actual storage different' do
      setup_actual_storage
      diffs = @storage_type.diff_against_actual('oy-different-001', [@mount_point_obj])

      expect(diffs).to match_array(["oy-different-001 differs: expected size '10485760.0' (KiB), but actual size is '5242880.0' (KiB)"])
    end

    it 'reports difference when extra actual storage present' do
      setup_actual_storage
      diffs = @storage_type.diff_against_actual('oy-extra-001', [@mount_point_obj])

      expect(diffs).to match_array(["oy-extra-001_extra differs: expected size '' (KiB), but actual size is '1048576.0' (KiB)"])
    end
  end

  describe 'archive' do
    it 'archives lv by renaming it' do
      time = Time.now.utc

      File.stub(:exists?) do |arg|
        case arg
        when '/dev/main/working'
          true
        end
      end

      @storage_type.should_receive(:cmd).with("lvrename main working a+#{time.to_i}.working")
      @storage_type.archive('working', @mount_point_obj, time)
    end

    it 'fails when archiving non-existent storage' do
      expect do
        @storage_type.archive('missing', @mount_point_obj, Time.now.utc)
      end.to raise_error("LV missing does not exist in VG main")
    end

    it 'fails when clashing with existing archive' do
      time = Time.now.utc

      File.stub(:exists?).and_return(true)

      expect do
        @storage_type.archive('clashes', @mount_point_obj, Time.now.utc)
      end.to raise_error("LV a+#{time.to_i}.clashes already exists in VG main")
    end
  end
end
