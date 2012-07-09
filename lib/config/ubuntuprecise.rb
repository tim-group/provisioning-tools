require 'provision/image/catalogue'
require 'provision/image/commands'

define "ubuntuprecise" do
  extend Provision::Image::Commands
  conventions()
  imagefile = "/images/#{hostname}.img"

  run("loopback devices") {
    cmd "mkdir #{temp_dir}"
    cmd "kvm-img create -fraw #{imagefile} 3G"
    cmd "losetup /dev/#{loop0} #{imagefile}"
    cmd "parted -sm /dev/#{loop0} mklabel msdos"
    supress_error.cmd "parted -sm /dev/#{loop0} mkpart primary ext3 1 100%"
    cmd "kpartx -a -v /dev/#{loop0}"
    cmd "mkfs.ext4 /dev/mapper/#{loop0}p1"
  }

  cleanup {
    while(`dmsetup ls | grep #{loop0}p1 | wc -l`.chomp != "0")
      puts "removing partition\n"
      cmd "kpartx -d /dev/#{loop0}"
      usleep 1
    end

   while(`losetup -a | grep /dev/#{loop0} | wc -l`.chomp != "0")
      cmd "losetup -d /dev/#{loop0}"
      usleep 1
      puts "loopback device has not been returned yet\n"
    end 
   cmd "rmdir #{temp_dir}"
  }

  run("loopback devices 2") {
    cmd "losetup /dev/#{loop1} /dev/mapper/#{loop0}p1"
    cmd "mount /dev/#{loop1} #{temp_dir}"
  }

  cleanup {
    cmd "umount -d /dev/#{loop1}"
    cmd "losetup -d /dev/#{loop1}"
    while(`losetup -a | grep /dev/#{loop1} | wc -l`.chomp != "0")
      usleep 1
    end
  }

  run("running debootstrap") {
#    cmd "debootstrap --arch amd64 precise #{temp_dir} http://aptproxy:3142/ubuntu"
    cmd "mkdir #{temp_dir}/proc"
    cmd "mkdir #{temp_dir}/sys"
    cmd "mkdir #{temp_dir}/dev"
  }


  run("mounting devices") {
    cmd "mount --bind /dev #{temp_dir}/dev"
    
    cmd "mount -t proc none #{temp_dir}/proc"
    cmd "mount -t sysfs none #{temp_dir}/sys"
  }

  cleanup {
    # FIXME Remove the sleep from here, ideally before dellis sees and stabs me.
    # Sleep required because prior steps do not release their file handles quick enough - or something.
    cmd "umount #{temp_dir}/proc"
    print    mnt=`mount -l | grep #{temp_dir}/proc | wc -l`.chomp 

   while(`mount -l | grep #{temp_dir}/proc | wc -l`.chomp != "0")
      usleep 1
    end


    cmd "umount #{temp_dir}/sys"
    while(`mount -l | grep #{temp_dir}/sys | wc -l`.chomp != "0")
      usleep 1
    end

    cmd "umount #{temp_dir}/dev"
    while(`mount -l | grep #{temp_dir}/dev | wc -l`.chomp != "0")
      usleep 1
    end
  }

end
