require 'provision/image/catalogue'
require 'provision/image/commands'

define "grow" do
  extend Provision::Image::Commands

  run("grow the partition table and filesystem") {
    case config[:vm_storage_type]
    when 'image'
      cmd "cp #{spec[:images_dir]}/gold/generic.img #{spec[:image_path]}"
      cmd "losetup /dev/#{spec[:loop0]} #{spec[:image_path]}"
      cmd "qemu-img resize #{spec[:image_path]} #{spec[:image_size]}"
      cmd "losetup -c /dev/#{spec[:loop0]}"
      vm_disk_location = "/dev/#{spec[:loop0]}"
    when 'lvm'
      cmd "lvcreate -n #{spec[:hostname]} -L #{spec[:image_size]} #{spec[:lvm_vg]}"
      cmd "dd if=#{spec[:images_dir]}/gold/generic.img of=/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      vm_disk_location = "/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
    else
      raise "provisioning tools does not know about vm_storage_type '#{config[:vm_storage_type]}'"
    end

    cmd "parted -s #{vm_disk_location} rm 1"
    cmd "parted -s #{vm_disk_location} mkpart primary ext3 2048s 100%"
    vm_partition_name = cmd "kpartx -l #{vm_disk_location} | awk '{ print $1 }'"
    cmd "kpartx -a #{vm_disk_location}"

    cmd "e2fsck -f -p /dev/mapper/#{vm_partition_name}"
    cmd "resize2fs /dev/mapper/#{vm_partition_name}"
  }

  on_error {
    case config[:vm_storage_type]
    when 'lvm'
      if File.exists("/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}")
        cmd "lvremove -f /dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      end
    end
  }

  cleanup {
    case config[:vm_storage_type]
    when 'image'
      cmd "kpartx -d /dev/#{spec[:loop0]}"
      cmd "losetup -d /dev/#{spec[:loop0]}"
    when 'lvm'
      cmd "kpartx -d /dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
    else
      raise "provisioning tools does not know about vm_storage_type '#{config[:vm_storage_type]}'"
    end
  }

end
