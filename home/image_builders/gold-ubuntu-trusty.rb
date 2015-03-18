require 'provision/image/catalogue'
require 'provision/image/commands'

# TODO:
# This file is legacy once gold images are built in a normal stacks way
# Its currecntly used by the bin/gold script, which will also go away.
# Please clean it up once that happens :)

define "gold-ubuntu-trusty" do
  extend Provision::Image::Commands

  run("loopback devices") do
    cmd "mkdir #{spec[:temp_dir]}"
    cmd "kvm-img create -fraw #{spec[:image_path]} 3G"
    cmd "losetup /dev/#{spec[:loop0]} #{spec[:image_path]}"
    cmd "parted -sm /dev/#{spec[:loop0]} mklabel msdos"
    suppress_error.cmd "parted -sm /dev/#{spec[:loop0]} mkpart primary ext3 1 100%"
    cmd "kpartx -a -v /dev/#{spec[:loop0]}"
    cmd "mkfs.ext4 /dev/mapper/#{spec[:loop0]}p1"
  end

  cleanup do
    keep_doing do
      suppress_error.cmd "kpartx -d /dev/#{spec[:loop0]}"
    end.until { `dmsetup ls | grep #{spec[:loop0]}p1 | wc -l`.chomp == "0" }

    cmd "udevadm settle"

    keep_doing do
      suppress_error.cmd "losetup -d /dev/#{spec[:loop0]}"
    end.until { `losetup -a | grep /dev/#{spec[:loop0]} | wc -l`.chomp == "0" }

    keep_doing do
      suppress_error.cmd "umount #{spec[:temp_dir]}"
      suppress_error.cmd "rmdir #{spec[:temp_dir]}"
    end.until { `ls -d  #{spec[:temp_dir]} 2> /dev/null | wc -l`.chomp == "0" }

    cmd "udevadm settle"
    cmd "rmdir #{spec[:temp_dir]}"
  end

  run("loopback devices 2") do
    cmd "losetup /dev/#{spec[:loop1]} /dev/mapper/#{spec[:loop0]}p1"
    cmd "mount /dev/#{spec[:loop1]} #{spec[:temp_dir]}"
  end

  cleanup do
    keep_doing do
      suppress_error.cmd "umount -d /dev/#{spec[:loop1]}"
      suppress_error.cmd "losetup -d /dev/#{spec[:loop1]}"
    end.until do
      `losetup -a | grep /dev/#{spec[:loop1]} | wc -l`.chomp == "0"
    end
  end

  run("running debootstrap") do
    cmd "debootstrap --arch amd64 --exclude=resolvconf,ubuntu-minimal trusty #{spec[:temp_dir]} http://aptproxy:3142/ubuntu"
    cmd "mkdir -p #{spec[:temp_dir]}/etc/default"
  end

  run("mounting devices") do
    cmd "mount --bind /dev #{spec[:temp_dir]}/dev"
    cmd "mount -t proc none #{spec[:temp_dir]}/proc"
    cmd "mount -t sysfs none #{spec[:temp_dir]}/sys"
  end

  cleanup do
    log.debug("cleaning up procs")
    log.debug(`mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp)
    keep_doing do
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/proc"
    end.until { `mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp == "0" }

    keep_doing do
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/sys"
    end.until { `mount -l | grep #{spec[:hostname]}/sys | wc -l`.chomp == "0" }

    keep_doing do
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/dev"
    end.until { `mount -l | grep #{spec[:hostname]}/dev | wc -l`.chomp == "0" }
  end

  run("set locale") do
    open("#{spec[:temp_dir]}/etc/default/locale", 'w') do |f|
      f.puts 'LANG="en_GB.UTF-8"'
    end
    chroot "locale-gen en_GB.UTF-8"
  end

  run("set timezone") do
    open("#{spec[:temp_dir]}/etc/timezone", 'w') do |f|
      f.puts 'Europe/London'
    end
    chroot "dpkg-reconfigure --frontend noninteractive tzdata"
  end

  run("set hostname") do
    open("#{spec[:temp_dir]}/etc/hostname", 'w') do |f|
      f.puts "#{spec[:hostname]}"
    end
    open("#{spec[:temp_dir]}/etc/dhcp/dhclient.conf", 'w') do |f|
      f.puts ""
    end
  end

  run("set root password") do
    chroot "echo 'root:root' | chpasswd"
  end

  run("deploy the root key") do
    cmd "mkdir -p #{spec[:temp_dir]}/root/.ssh/"
    #    cmd "cp #{Dir.pwd}/files/id_rsa.pub #{spec[:temp_dir]}/root/.ssh/authorized_keys"
  end

  run("enable serial so we can use virsh console") do
    open("#{spec[:temp_dir]}/etc/init/ttyS0.conf", 'w') do |f|
      f.puts """
start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]
respawn
exec /sbin/getty -L ttyS0 115200 vt102
    """
    end
  end

  run("install misc packages") do
    apt_install "acpid openssh-server curl vim dnsutils lsof"
  end

  # A few daemons hang around at the end of the bootstrapping process that prevent us unmounting.
  cleanup do
    chroot "/etc/init.d/dbus stop"
    chroot "/etc/init.d/acpid stop"
    chroot "/etc/init.d/cron stop"
    chroot "/etc/init.d/udev stop"
    chroot "/etc/init.d/rsyslog stop"
    chroot "killall -9u syslog"
  end

  run("configure trusty repo") do
    open("#{spec[:temp_dir]}/etc/apt/sources.list", 'w') do |f|
      f.puts "deb http://gb.archive.ubuntu.com/ubuntu/ trusty main\n"
      f.puts "deb http://gb.archive.ubuntu.com/ubuntu/ trusty universe\n"
      f.puts "deb http://gb.archive.ubuntu.com/ubuntu/ trusty-updates main\n"
      f.puts "deb http://gb.archive.ubuntu.com/ubuntu/ trusty-updates universe\n"
      f.puts "deb http://deb.youdevise.com trusty main\n"
      f.puts "deb http://deb.youdevise.com all main\n"
      f.puts "deb http://deb-transitional.youdevise.com/stable trusty main\n"
      f.puts "deb http://deb-transitional.youdevise.com/stable all main\n"
    end
    chroot "curl -Ss http://deb.youdevise.com/pubkey.gpg | apt-key add -"
    chroot "curl -Ss http://deb-transitional.youdevise.com/pubkey.gpg | apt-key add -"
  end

  run("prevent apt from making stupid suggestions") do
    open("#{spec[:temp_dir]}/etc/apt/apt.conf.d/99no-recommends", 'w') do |f|
      f.puts "APT::Install-Recommends \"false\";\n"
      f.puts "APT::Install-Suggests \"false\";\n"
    end
  end

  run("configure aptproxy") do
    open("#{spec[:temp_dir]}/etc/apt/apt.conf.d/01proxy", 'w') do |f|
      f.puts "Acquire::http::Proxy \"http://#{spec[:aptproxy]}:3142\";\n"
    end
  end

  run("ensure the correct mailutils gets instaled") do
    open("#{spec[:temp_dir]}/etc/apt/preferences.d/mailutils", 'w') do |f|
      f.puts "Package: mailutils
Pin: release o=TIMGroup,a=trusty
Pin-Priority: 1001\n"
    end
    open("#{spec[:temp_dir]}/etc/apt/preferences.d/libmailutils2", 'w') do |f|
      f.puts "Package: libmailutils2
Pin: release o=TIMGroup,a=trusty
Pin-Priority: 1001\n"
    end
  end

  run("run apt-update ") do
    chroot "apt-get -y --force-yes update"
  end

  run("temp fix to update ssl packages for puppet to run") do
    chroot "DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes dist-upgrade"
  end

  run("install some other useful stuff") do
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
    apt_install "postfix"
  end

  run("install puppet managed packages to speed up initial runs") do
    apt_install "collectd"
    apt_install "dstat"
    apt_install "git-svn"
    apt_install "htop"
    apt_install "iftop"
    apt_install "iotop"
    apt_install "libnet-ping-ruby"
    apt_install "libstomp-ruby1.8"
    apt_install "lvm2"
    apt_install "mailutils"
    apt_install "nagios-nrpe-server"
    apt_install "nagios-plugins"
    apt_install "nagios-plugins-standard"
    apt_install "screen"
    apt_install "strace"
    apt_install "subversion"
    apt_install "sysstat"
    apt_install "tmux"
    apt_install "unzip"
    apt_install "zip"
    apt_install "zsh"
  end

  run("pre-accept sun licences") do
    open("#{spec[:temp_dir]}/var/cache/debconf/java-license.seeds", 'w') do |f|
      f.puts """
sun-java6-bin   shared/accepted-sun-dlj-v1-1    boolean true
sun-java6-jdk   shared/accepted-sun-dlj-v1-1    boolean true
sun-java6-jre   shared/accepted-sun-dlj-v1-1    boolean true
sun-java6-jre   sun-java5-jre/stopthread        boolean true
sun-java6-jre   sun-java5-jre/jcepolicy         note
sun-java6-bin   shared/present-sun-dlj-v1-1     note
sun-java6-jdk   shared/present-sun-dlj-v1-1     note
sun-java6-jre   shared/present-sun-dlj-v1-1     note
    """
    end

    chroot "/usr/bin/debconf-set-selections /var/cache/debconf/java-license.seeds"

    apt_install "sun-java6-jdk"
    apt_install "sun-java6-jre"
  end

  run("install kernel and grub") do
    chroot "apt-get -y --force-yes update"
    apt_install "linux-image-virtual"
    apt_install "grub-pc"
    cmd "mkdir -p #{spec[:temp_dir]}/boot/grub"
    cmd "tune2fs -Lmain /dev/#{spec[:loop1]}"

    open("#{spec[:temp_dir]}/boot/grub/device.map", 'w') do |f|
      f.puts "(hd0) /dev/#{spec[:loop0]}"
      f.puts "(hd0,1) /dev/#{spec[:loop1]}"
    end

    find_kernel = `ls -c #{spec[:temp_dir]}/boot/vmlinuz-* | head -1`.chomp
    find_kernel =~ /vmlinuz-(.+)/
    kernel_version = $1

    kernel = "/boot/vmlinuz-#{kernel_version}"
    initrd = "/boot/initrd.img-#{kernel_version}"
    uuid = `blkid -o value /dev/mapper/#{spec[:loop0]}p1 | head -n1`.chomp

    open("#{spec[:temp_dir]}/boot/grub/grub.cfg", 'w') do |f|
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
    end

    chroot "grub-install --no-floppy --grub-mkdevicemap=/boot/grub/device.map /dev/#{spec[:loop0]}"
  end

  run("remove cached packages") do
#    chroot "rm -rf /var/cache/apt/archives/*"
    chroot "DEBIAN_FRONTEND=noninteractive apt-get clean"
  end

  run("download packages that we would like") do
    apt_download "mcollective"
    apt_download "puppet"
  end

  run("Fix up remote logging") do
    # This will get overridden by the local logcollector when puppet runs, but that's fine.
    # In the meantime, we throw syslogd at a CNAME whilst we bootstrap
    open("#{spec[:temp_dir]}/etc/rsyslog.d/00-logcollector.conf", 'w') do |f|
      f.puts '*.* @logs'
    end
  end

  run("Fix syslog rate limiting") do
    open("/etc/rsyslog.conf", 'a') do |f|
      f.puts '$SystemLogRateLimitInterval 0
      $SystemLogRateLimitBurst 0'
    end
  end

  run("install ntp and give it a sensible default config") do
    apt_install "ntp"
    open("#{spec[:temp_dir]}/etc/ntp.conf", 'w') do |f|
      f.puts <<-EOF
driftfile /var/lib/ntp/ntp.drift

# Enable this if you want statistics to be logged.
#statsdir /var/log/ntpstats/

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

# You do need to talk to an NTP server or two (or three).
server ntp1

# Access control configuration; see /usr/share/doc/ntp-doc/html/accopt.html for
# details.  The web page <http://support.ntp.org/bin/view/Support/AccessRestrictions>
# might also be helpful.
#
# Note that "restrict" applies to both servers and clients, so a configuration
# that might be intended to block requests from certain clients could also end
# up blocking replies from your own upstream servers.

# By default, exchange time with everybody, but don't allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod notrap nomodify nopeer noquery

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1

# Clients from this (example!) subnet have unlimited access, but only if
# cryptographically authenticated.
#restrict 192.168.123.0 mask 255.255.255.0 notrust


# If you want to provide time to your local subnet, change the next line.
# (Again, the address is an example only.)
#broadcast 192.168.123.255

# If you want to listen to time broadcasts on your local subnet, de-comment the
# next lines.  Please do this only if you trust everybody on the network!
#disable auth
#broadcastclient
EOF
    end
  end
end
