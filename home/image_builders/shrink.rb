require 'provision/image/catalogue'
require 'provision/image/commands'

define "shrink" do
  extend Provision::Image::Commands

  run("loopback devices") {
    cmd "losetup /dev/#{spec[:loop0]} #{spec[:image_path]}"
    cmd "kpartx -a /dev/#{spec[:loop0]}"
    cmd "e2fsck -f -p /dev/mapper/#{spec[:loop0]}p1"
    cmd "resize2fs -M /dev/mapper/#{spec[:loop0]}p1"

    blockcount = `dumpe2fs -h /dev/mapper/#{spec[:loop0]}p1 | grep -F "Block count:" | awk -F ':' '{ print $2 }' | sed 's/ //g'`.chomp.to_i

    blocksize = `sudo dumpe2fs -h /dev/mapper/#{spec[:loop0]}p1 | grep -F "Block size:" | awk -F ':' '{ print $2 }' | sed 's/ //g'`.chomp.to_i

    sectors=(blockcount*blocksize/512)+2048
    cmd "parted -s /dev/#{spec[:loop0]} rm 1"
    cmd "parted -s /dev/#{spec[:loop0]} mkpart primary ext3 2048s #{sectors}s"

    newsize=`parted -sm /dev/#{spec[:loop0]} print | grep -e '^1:' | awk -F ':' '{ print $3 }'`

    cmd "qemu-img resize #{spec[:image_path]} #{newsize}"
  }

  cleanup {
    keep_doing {
      supress_error.cmd "kpartx -d /dev/#{spec[:loop0]}"
    }.until {`dmsetup ls | grep #{spec[:loop0]}p1 | wc -l`.chomp == "0"}

    cmd "losetup -d /dev/#{spec[:loop0]}"
  }
end
