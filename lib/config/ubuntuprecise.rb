require 'provision/catalogue'
require 'provision/commands'

extend Provision::Commands

define "ubuntuprecise" do
  vm_name = ARGV[0] || 'vm1'
  temp_dir = 'vmtmp-'
  #+ rand(36**8).to_s(36)

  run("loopback devices") {
    @loop0 = "loop0" #File.basename(`losetup -f`).chomp
    cmd "mkdir #{temp_dir}"
    cmd "kvm-img create -fraw #{vm_name}.img 3G"
    cmd "losetup /dev/#{@loop0} #{vm_name}.img"
    cmd "parted -sm /dev/#{@loop0} mklabel msdos"
    cmd_ignore "parted -sm /dev/#{@loop0} mkpart primary ext3 1 100%"
    cmd "kpartx -a -v /dev/#{@loop0}"
    cmd "mkfs.ext4 /dev/mapper/#{@loop0}p1"
  }

  cleanup {
    cmd_ignore "kpartx -d /dev/#{@loop0}"
    cmd_ignore "losetup -d /dev/#{@loop0}"
    cmd_ignore "rmdir #{temp_dir}"
  }

  run("loopback devices 2") {
    @loop1 = "loop1" #File.basename(`losetup -f`).chomp
    cmd "losetup /dev/#{@loop1} /dev/mapper/#{@loop0}p1"
    cmd "mount /dev/#{@loop1} #{temp_dir}"
  }

  cleanup {
    cmd_ignore "umount /dev/#{@loop1}"
    cmd_ignore "losetup -d /dev/#{@loop1}"
  }

#  run("running debootstrap") {
#    cmd "debootstrap --arch amd64 precise #{temp_dir} http://aptproxy:3142/ubuntu"
#  }

  run("mounting devices") {
    cmd "mount --bind /dev #{temp_dir}/dev"
    chroot "#{temp_dir}","mount -t proc none /proc"
    chroot "#{temp_dir}","mount -t sysfs none /sys"
  }

  cleanup {
    # FIXME Remove the sleep from here, ideally before dellis sees and stabs me.
    # Sleep required because prior steps do not release their file handles quick enough - or something.
    chroot_ignore "#{temp_dir}","umount /proc"
    chroot_ignore "#{temp_dir}","umount /sys"
    chroot_ignore "#{temp_dir}","sleep 1; umount #{temp_dir}/dev"
  }

  run("set locale") {
    open("#{temp_dir}/etc/default/locale", 'w') { |f|
      f.puts 'LANG="en_GB.UTF-8"'
    }

    chroot "#{temp_dir}", "locale-gen en_GB.UTF-8"
  }

  run("set timezone") {
    open("#{temp_dir}/etc/timezone", 'w') { |f|
      f.puts 'Europe/London'
    }

    chroot "#{temp_dir}", "dpkg-reconfigure --frontend noninteractive tzdata"
  }

  run("set hostname") {
    open("#{temp_dir}/etc/hostname", 'w') { |f|
      f.puts "#{vm_name}"
    }
  }

  run("install kernel and grub") {
    chroot "#{temp_dir}", "apt-get -y --force-yes update"
    chroot "#{temp_dir}","DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install linux-image-virtual"
    chroot "#{temp_dir}","DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install grub-pc"
    cmd "mkdir -p #{temp_dir}/boot/grub"

    open("#{temp_dir}/boot/grub/device.map", 'w') { |f|
      f.puts "(hd0) /dev/#{loop0}"
      f.puts "(hd0,1) /dev/#{loop1}"
    }

    kernel_version = "3.2.0-23-virtual"
    kernel = "/boot/vmlinuz-#{kernel_version}"
    initrd = "/boot/initrd.img-#{kernel_version}"
    uuid = `blkid -o value /dev/mapper/#{loop0}p1 | head -n1`.chomp

    open("#{temp_dir}/boot/grub/grub.cfg", 'w') { |f|
      f.puts "
          set default=\"0\"
          set timeout=1
          menuentry 'Ubuntu, with Linux #{kernel_version}' --class ubuntu --class gnu-linux --class gnu --class os {
          insmod part_msdos
          insmod ext2
          set root='(hd0,1)'
          linux #{kernel} root=/dev/disk/by-uuid/#{uuid} ro
          initrd #{initrd}
          }"
    }

    chroot "#{temp_dir}", "grub-install --no-floppy --grub-mkdevicemap=/boot/grub/device.map /dev/#{loop0}"
  }

  run("set root password") {
    chroot "#{temp_dir}","echo 'root:root' | chpasswd"
  }

  run("set up basic networking") {
    open("#{temp_dir}/etc/network/interfaces", 'w') { |f|
      f.puts "
     # The loopback network interface
     auto lo
     iface lo inet loopback
     # The primary network interface
     auto eth0
     iface eth0 inet dhcp
       "
    }
  }

  run("install misc packages") {
    chroot "#{temp_dir}","DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install acpid openssh-server curl vim"
  }

  # A few daemons hang around at the end of the bootstrapping process that prevent us unmounting.
  cleanup {
    chroot "#{temp_dir}","/etc/init.d/acpid stop"
    chroot "#{temp_dir}","/etc/init.d/cron stop"
  }

  run("configure youdevise apt repo") {
    open("#{temp_dir}/etc/apt/sources.list.d/youdevise.list", 'w') { |f|
      f.puts "deb http://apt/ubuntu stable main\ndeb-src http://apt/ubuntu stable main\n"
    }

    chroot "#{temp_dir}","curl -Ss http://apt/ubuntu/repo.key | apt-key add -"
  }
end