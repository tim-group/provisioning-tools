class Commands
  def initialize
    @tidyup=[]
  end

  def chroot(dir, command, tidyup=nil)
    chroot_tidyup = "chroot dir -c /bin/bash #{tidyup}" if tidyup!=nil
    cmd("chroot dir -c /bin/bash #{command}" ,chroot_tidyup)
  end

  def cmd(command, tidyup=nil)
    if ! system("#{command}  >> console.txt 2>&1")
      raise "command returned non-zero error code"
    end

    if (tidyup!=nil)
      @tidyup << lambda {system("#{tidyup} >> console.txt  2>&1 ")}
    end
  end

  def tidyup
    @tidyup.reverse.each {|tidy|
      tidy.call()
    }
  end
end

module Command
  @@commands = Commands.new()
  def run txt, &block
    print "#{txt}\t\t"
    error = nil
    begin
      @@commands.instance_eval(&block)
    rescue Exception=>e
      error=e
    ensure
      if (not error.nil?)
        print "[\e[0;31mFAILED\e[0m]\n"
        raise error
      else
        print "[\e[0;32mDONE\e[0m]\n"
      end
    end
  end

  def tidyup
    print "tidying up\t\t\t"
    @@commands.tidyup()
    print "[\e[0;32mDONE\e[0m]\n"
  end
end

include Command

begin
  run("loopback devices") {
    cmd 'mkdir dir', 'rm -rf dir'
    cmd 'kvm-img create -fraw disk.img 3G'
    cmd "losetup /dev/loop0 disk.img", "losetup -d /dev/loop0"
    cmd "parted /dev/loop0 mklabel msdos"
    cmd "parted /dev/loop0 mkpart primary ext3 1 100%"
    cmd "kpartx -a -v /dev/loop0", "kpartx -d /dev/loop0"
    cmd "mkfs.ext4 /dev/mapper/loop0p1"
    cmd "losetup /dev/loop1 /dev/mapper/loop0p1", "losetup -d /dev/loop1"
    cmd "mount /dev/loop1 dir", "umount /dev/loop1"
  }

  run("running debootstrap") {
    cmd "debootstrap --verbose --arch amd64 precise ${MOUNT_DIR} http://aptproxy:3142/ubuntu"
  }

  run("mounting devices") {
    cmd "mount --bind /dev dir/dev", "umount dir/dev"
    chroot "dir","mount -t proc none /proc", "umount /proc"
    chroot "dir","mount -t sysfs none /sys", "umount /sys"
  }

  run("install kernel and grub") {
    chroot "dir","apt-get install linux-image"
    chroot "dir","apt-get install grub-pc"
    cmd "
  mkdir -p dir/boot/grub
  cat > dir/boot/grub/device.map << EOF
  (hd0 /dev/loop0
  (hd0,1 /dev/loop1
  EOF"
    cmd "dir","grub-mkconfig -o /boot/grub/grub.cfg"
    cmd "dir", "grub-install --no-floppy --grub-mkdevicemap=/boot/grub/device.map /dev/loop0"
  }
rescue
ensure
  tidyup()
end