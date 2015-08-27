module Provision::Storage::Commands
  def create_partition(device, fs_type, lvm)
    fail_if_arg_empty('device', device)
    fail_if_arg_empty('fs_type', fs_type)
    fail_if_arg_not_bool('lvm', lvm)
    cmd "parted -s #{device} mklabel msdos"
    cmd "parted -s #{device} mkpart primary #{fs_type} 2048s 100%"
    cmd "parted -s #{device} set 1 lvm on" if lvm
  end

  def kpartxa_new(device)
    fail_if_arg_empty('device', device)
    cmd "udevadm settle"
    cmd "kpartx -av #{device}"
  end

  def kpartxd_new(device)
    fail_if_arg_empty('device', device)
    cmd "udevadm settle"
    cmd "kpartx -dv #{device}"
  end

  def kpartxl(device)
    fail_if_arg_empty('device', device)
    cmd "udevadm settle"
    cmd "kpartx -l #{device}"
  end

  def create_lvm_pv(device)
    fail_if_arg_empty('device', device)
    cmd "pvcreate #{device}"
  end

  def force_remove_lvm_pv(device)
    fail_if_arg_empty('device', device)
    cmd "pvremove -ff -y #{device}"
  end

  def create_lvm_vg(vg_name, device)
    fail_if_arg_empty('vg_name', vg_name)
    fail_if_arg_empty('device', device)
    cmd "vgcreate #{vg_name} #{device}"
  end

  def disable_lvm_vg(vg_name)
    fail_if_arg_empty('vg_name', vg_name)
    cmd "vgchange -an #{vg_name}"
  end

  def disable_lvm_lv(lv_name)
    fail_if_arg_empty('lv_name', lv_name)
    cmd "lvchange -an #{lv_name}"
  end

  def create_lvm_lv(lv_name, vg_name, size)
    fail_if_arg_empty('lv_name', lv_name)
    fail_if_arg_empty('vg_name', vg_name)
    fail_if_arg_empty('size', size)
    fail("LV #{lv_name} already exists in VG #{vg_name}") if File.exists?("/dev/#{vg_name}/#{lv_name}")
    cmd "lvcreate -L #{size} -n #{lv_name} #{vg_name}"
  end

  def remove_lvm_lv(lv_name, vg_name)
    fail_if_arg_empty('lv_name', lv_name)
    fail_if_arg_empty('vg_name', vg_name)
    output = "LV doesn't exist"
    100.times do |i|
      break unless File.exists?("/dev/#{vg_name}/#{lv_name}")
      begin
        output = cmd "lvremove -f #{vg_name}/#{lv_name}" if File.exists?("/dev/#{vg_name}/#{lv_name}")
      rescue Exception => e
        raise("failed to remove LV #{lv_name} from VG #{vg_name} due to exception #{e}") if i >= 99
        @log.debug("failed to remove LV #{lv_name} from VG #{vg_name} on try #{i} due to exception #{e}")
      end
    end
    output
  end

  def destroy_partition_table_and_metadata(device)
    fail_if_arg_empty('device', device)
    cmd "dd if=/dev/zero of=#{device} bs=512k count=10" if File.exists?(device)
  end

  def fail_if_arg_empty(name, arg)
    fail("Argument #{name} is empty or not a string") unless arg.is_a?(String) && arg.strip.match(/\s/).nil?
  end

  def fail_if_arg_not_bool(name, arg)
    fail("Argument #{name} is not a boolen") unless arg.is_a?(TrueClass) || arg.is_a?(FalseClass)
  end
end
