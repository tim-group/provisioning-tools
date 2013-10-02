require 'provision/image/catalogue'
require 'provision/image/commands'

define "grow" do
  extend Provision::Image::Commands

  case spec[:vm_storage_type]
  when 'image'
    run("grow the partition table and filesystem") {
      cmd "cp #{spec[:images_dir]}/gold/generic.img #{spec[:image_path]}"
      cmd "losetup /dev/#{spec[:loop0]} #{spec[:image_path]}"
      cmd "qemu-img resize #{spec[:image_path]} #{spec[:image_size]}"
      cmd "losetup -c /dev/#{spec[:loop0]}"
      cmd "parted -s /dev/#{spec[:loop0]} rm 1"
      cmd "parted -s /dev/#{spec[:loop0]} mkpart primary ext3 2048s 100%"
      cmd "kpartx -a /dev/#{spec[:loop0]}"
      cmd "e2fsck -f -p /dev/mapper/#{spec[:loop0]}p1"
      cmd "resize2fs /dev/mapper/#{spec[:loop0]}p1"
    }

    cleanup {
      cmd "kpartx -d /dev/#{spec[:loop0]}"
      cmd "losetup -d /dev/#{spec[:loop0]}"
    }
  when 'lvm'
    run("grow the partition table and filesystem") {
      puts "1"
      cmd "lvcreate -n #{spec[:hostname]} -L #{spec[:image_size]} #{spec[:lvm_vg]}"
      cmd "dd if=#{spec[:images_dir]}/gold/generic.img of=/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      cmd "parted -s /dev/#{spec[:lvm_vg]}/#{spec[:hostname]} rm 1"
      cmd "parted -s /dev/#{spec[:lvm_vg]}/#{spec[:hostname]} mkpart primary ext3 2048s 100%"
      cmd "kpartx -a /dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      cmd "e2fsck -f -p /dev/mapper/#{spec[:lvm_vg]}-#{spec[:hostname].gsub(/-/,'--')}1"
      cmd "resize2fs /dev/mapper/#{spec[:lvm_vg]}-#{spec[:hostname].gsub(/-/,'--')}1"
    }

    cleanup {
      cmd "kpartx -d /dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
    }
  else
    raise "provisioning tools does not know about vm_storage_type '#{spec[:vm_storage_type]}'"
  end
end
