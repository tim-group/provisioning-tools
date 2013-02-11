require 'provision/image/catalogue'
require 'provision/image/commands'

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
    keep_doing {
    supress_error.cmd "kpartx -d /dev/#{spec[:loop0]}"
  }.until {`dmsetup ls | grep #{spec[:loop0]}p1 | wc -l`.chomp == "0"}

  cmd "udevadm settle"

  keep_doing {
    supress_error.cmd "losetup -d /dev/#{spec[:loop0]}"
  }.until {`losetup -a | grep /dev/#{spec[:loop0]} | wc -l`.chomp == "0"}

  keep_doing {
    supress_error.cmd "umount #{spec[:temp_dir]}"
    supress_error.cmd "rmdir #{spec[:temp_dir]}"
  }.until {`ls -d  #{spec[:temp_dir]} 2> /dev/null | wc -l`.chomp == "0"}

  cmd "udevadm settle"
  cmd "rmdir #{spec[:temp_dir]}"
  }

  run("loopback devices 2") {
    cmd "losetup /dev/#{spec[:loop1]} /dev/mapper/#{spec[:loop0]}p1"
    cmd "mount /dev/#{spec[:loop1]} #{spec[:temp_dir]}"
  }

  cleanup {
    keep_doing {
      supress_error.cmd "umount -d /dev/#{spec[:loop1]}"
      supress_error.cmd "losetup -d /dev/#{spec[:loop1]}"
    }.until {
      `losetup -a | grep /dev/#{spec[:loop1]} | wc -l`.chomp == "0"
    }
  }

  run("running debootstrap") {
    cmd "debootstrap --arch amd64 --exclude=resolvconf,ubuntu-minimal precise #{spec[:temp_dir]} http://aptproxy:3142/ubuntu"
    cmd "mkdir -p #{spec[:temp_dir]}/etc/default"
  }

  run("mounting devices") {
    cmd "mount --bind /dev #{spec[:temp_dir]}/dev"
    cmd "mount -t proc none #{spec[:temp_dir]}/proc"
    cmd "mount -t sysfs none #{spec[:temp_dir]}/sys"
  }

  cleanup {
    log.debug("cleaning up procs")
    log.debug(`mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp)
    keep_doing {
      supress_error.cmd "umount -l #{spec[:temp_dir]}/proc"
    }.until {`mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp == "0"}

    keep_doing {
      supress_error.cmd "umount -l #{spec[:temp_dir]}/sys"
    }.until {`mount -l | grep #{spec[:hostname]}/sys | wc -l`.chomp == "0"}

    keep_doing {
      supress_error.cmd "umount -l #{spec[:temp_dir]}/dev"
    }.until {`mount -l | grep #{spec[:hostname]}/dev | wc -l`.chomp == "0"}
  }

  run("set locale") {
    open("#{spec[:temp_dir]}/etc/default/locale", 'w') { |f|
      f.puts 'LANG="en_GB.UTF-8"'
    }
    chroot "locale-gen en_GB.UTF-8"
  }

  run("set timezone") {
    open("#{spec[:temp_dir]}/etc/timezone", 'w') { |f|
      f.puts 'Europe/London'
    }
    chroot "dpkg-reconfigure --frontend noninteractive tzdata"
  }

  run("set hostname") {
    open("#{spec[:temp_dir]}/etc/hostname", 'w') { |f|
      f.puts "#{spec[:hostname]}"
    }
    open("#{spec[:temp_dir]}/etc/dhcp/dhclient.conf", 'w') { |f|
f.puts ""
    }
  }

  run("set root password") {
    chroot "echo 'root:root' | chpasswd"
  }

  run("deploy the root key") {
    cmd "mkdir -p #{spec[:temp_dir]}/root/.ssh/"
    #    cmd "cp #{Dir.pwd}/files/id_rsa.pub #{spec[:temp_dir]}/root/.ssh/authorized_keys"
  }

  run("enable serial so we can use virsh console") {
    open("#{spec[:temp_dir]}/etc/init/ttyS0.conf", 'w') { |f|
      f.puts """
start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]
respawn
exec /sbin/getty -L ttyS0 115200 vt102
    """
    }
  }

  run("install misc packages") {
    apt_install "acpid openssh-server curl vim dnsutils lsof"
  }

  # A few daemons hang around at the end of the bootstrapping process that prevent us unmounting.
  cleanup {
    chroot "/etc/init.d/dbus stop"
    chroot "/etc/init.d/acpid stop"
    chroot "/etc/init.d/cron stop"
    chroot "/etc/init.d/udev stop"
  }

  run("configure precise repo") {
    open("#{spec[:temp_dir]}/etc/apt/sources.list", 'w') { |f|
      f.puts "deb http://gb.archive.ubuntu.com/ubuntu/ precise main\n"
      f.puts "deb http://gb.archive.ubuntu.com/ubuntu/ precise universe\n"
      f.puts "deb http://gb.archive.ubuntu.com/ubuntu/ precise-updates main\n"
      f.puts "deb http://gb.archive.ubuntu.com/ubuntu/ precise-updates universe\n"
    }
  }

  run("configure youdevise apt repo") {
    open("#{spec[:temp_dir]}/etc/apt/sources.list.d/youdevise.list", 'w') { |f|
      f.puts "deb http://apt/ubuntu stable main\ndeb-src http://apt/ubuntu stable main\n"
    }
    chroot "curl -Ss http://apt/ubuntu/repo.key | apt-key add -"
  }

  run("prevent apt from making stupid suggestions") {
    open("#{spec[:temp_dir]}/etc/apt/apt.conf.d/99no-recommends", 'w') { |f|
      f.puts "APT::Install-Recommends \"false\";\n"
      f.puts "APT::Install-Suggests \"false\";\n"
    }
  }

  run("configure aptproxy") {
    open("#{spec[:temp_dir]}/etc/apt/apt.conf.d/01proxy", 'w') { |f|
      f.puts "Acquire::http::Proxy \"http://#{spec[:aptproxy]}:3142\";\n"
    }
  }

  run("run apt-update ") {
    chroot "apt-get -y --force-yes update"
  }

  run("temp fix to update ssl packages for puppet to run") {
    chroot "DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes dist-upgrade"
  }

  run("install some other useful stuff") {
    apt_install "nagios-nrpe-server"
    apt_install "psmisc"
    apt_install "vim"
    apt_install "nmap"
    apt_install "traceroute"
    apt_install "tcptraceroute"
    apt_install "ngrep"
    apt_install "tcpdump"
    apt_install "git-core"
    apt_install "rubygems"
    apt_install "libstomp-ruby"
    apt_install "iptables"
    apt_install "telnet"
  }

  run("download packages that we would like") {
    apt_download "mcollective"
    apt_download "puppet"
  }

  cleanup {
#    chroot "rm -rf /var/cache/apt/archives/*"
  }

  run("install kernel and grub") {
    chroot "apt-get -y --force-yes update"
    apt_install "linux-image-virtual"
    apt_install "grub-pc"
    cmd "mkdir -p #{spec[:temp_dir]}/boot/grub"
    cmd "tune2fs -Lmain /dev/#{spec[:loop1]}"

    open("#{spec[:temp_dir]}/boot/grub/device.map", 'w') { |f|
      f.puts "(hd0) /dev/#{spec[:loop0]}"
      f.puts "(hd0,1) /dev/#{spec[:loop1]}"
    }

    find_kernel = `ls -c #{spec[:temp_dir]}/boot/vmlinuz-* | head -1`.chomp
    find_kernel =~ /vmlinuz-(.+)/
    kernel_version = $1

puts "KERNEL FOUND IS #{kernel_version} ****************"

    kernel = "/boot/vmlinuz-#{kernel_version}"
    initrd = "/boot/initrd.img-#{kernel_version}"
    uuid = `blkid -o value /dev/mapper/#{spec[:loop0]}p1 | head -n1`.chomp

    open("#{spec[:temp_dir]}/boot/grub/grub.cfg", 'w') { |f|
      f.puts "
          set default=\"0\"
          set timeout=1
          menuentry 'Ubuntu, with Linux #{kernel_version}' --class ubuntu --class gnu-linux --class gnu --class os {
          insmod part_msdos
          insmod ext2
          set root='(hd0,1)'
          search --label --no-floppy --set=root main
          linux #{kernel} root=/dev/disk/by-label/main ro
          initrd #{initrd}
          }"
    }

    chroot "grub-install --no-floppy --grub-mkdevicemap=/boot/grub/device.map /dev/#{spec[:loop0]}"
  }


end
