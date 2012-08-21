require 'provision/image/catalogue'
require 'provision/image/commands'
require 'yaml'

define "ubuntuprecise" do
  extend Provision::Image::Commands

  run("loopback devices") {
    cmd "mkdir #{spec[:temp_dir]}"
    cmd "kvm-img create -fraw #{spec[:image_path]} 3G"
    cmd "losetup /dev/#{spec[:loop0]} #{spec[:image_path]}"
    cmd "parted -sm /dev/#{spec[:loop0]} mklabel msdos"
    supress_error.cmd "parted -sm /dev/#{spec[:loop0]} mkpart primary ext3 1 100%"
    cmd "kpartx -a -v /dev/#{spec[:loop0]}"
    cmd "mkfs.ext4 /dev/mapper/#{spec[:loop0]}p1"
  }

  cleanup {
    while(`dmsetup ls | grep #{spec[:loop0]}p1 | wc -l`.chomp != "0")
      cmd "kpartx -d /dev/#{spec[:loop0]}"
      sleep(0.1)
    end
    cmd "udevadm settle"

    while(`losetup -a | grep /dev/#{spec[:loop0]} | wc -l`.chomp != "0")
      cmd "losetup -d /dev/#{spec[:loop0]}"
      sleep(0.1)
    end

    while (`ls -d  #{spec[:temp_dir]} 2> /dev/null | wc -l`.chomp != "0")
      cmd "umount #{spec[:temp_dir]}"
      cmd "rmdir #{spec[:temp_dir]}"
      sleep(0.1)
    end
    cmd "udevadm settl"
  }

  run("loopback devices 2") {
    cmd "losetup /dev/#{spec[:loop1]} /dev/mapper/#{spec[:loop0]}p1"
    cmd "mount /dev/#{spec[:loop1]} #{spec[:temp_dir]}"
  }

  cleanup {
    while(`losetup -a | grep /dev/#{spec[:loop1]} | wc -l`.chomp != "0")
      cmd "umount -d /dev/#{spec[:loop1]}"
      cmd "losetup -d /dev/#{spec[:loop1]}"
    end
  }

  run("running debootstrap") {
    #    cmd "debootstrap --arch amd64 precise #{spec[:temp_dir]} http://aptproxy:3142/ubuntu"
    cmd "mkdir #{spec[:temp_dir]}/proc"
    cmd "mkdir #{spec[:temp_dir]}/sys"
    cmd "mkdir #{spec[:temp_dir]}/dev"
  }

  run("mounting devices") {
    cmd "mount --bind /dev #{spec[:temp_dir]}/dev"
    cmd "mount -t proc none #{spec[:temp_dir]}/proc"
    cmd "mount -t sysfs none #{spec[:temp_dir]}/sys"
  }

  cleanup {
    # FIXME Remove the sleep from here, ideally before dellis sees and stabs me.
    # Sleep required because prior steps do not release their file handles quick enough - or something.

    while(`mount -l | grep #{spec[:temp_dir]}/proc | wc -l`.chomp != "0")
      cmd "umount #{spec[:temp_dir]}/proc"
      sleep(0.5)
    end

    while (`mount -l | grep #{spec[:temp_dir]}/sys | wc -l`.chomp != "0")
      cmd "umount #{spec[:temp_dir]}/sys"
      sleep(0.5)
    end

    while( `mount -l | grep #{spec[:temp_dir]}/dev | wc -l`.chomp != "0")
      cmd "umount #{spec[:temp_dir]}/dev"
      sleep(0.5)
    end
  }
end