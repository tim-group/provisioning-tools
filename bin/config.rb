define "ubuntu-precise" do |block|
  run("loopback devices") {
    cmd "mkdir dir"
    cmd 'kvm-img create -fraw disk.img 3G'
    cmd "losetup /dev/loop0 disk.img"
    cmd "parted /dev/loop0 mklabel msdos"
    cmd "parted /dev/loop0 mkpart primary ext3 1 100%"
    cmd "kpartx -a -v /dev/loop0"
    cmd "mkfs.ext4 /dev/mapper/loop0p1"
    cmd "losetup /dev/loop1 /dev/mapper/loop0p1"
    cmd "mount /dev/loop1 dir"

    cleanup {
      cmd "umount /dev/loop1"
      cmd "losetup -d /dev/loop1"
      cmd "kpartx -d /dev/loop0"
      cmd "losetup -d /dev/loop0"
      cmd "rm -rf dir"
    }

    block.call()
  }

  block.call()
end

define "puppetmaster" do
  template "ubuntu-precise" do
    cmd "echo 'building puppet'"
  end
end

template "puppetmaster" do
end