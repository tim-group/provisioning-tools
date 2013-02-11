require 'provision/image/catalogue'
require 'provision/image/commands'

define "grow" do
  extend Provision::Image::Commands

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
end
