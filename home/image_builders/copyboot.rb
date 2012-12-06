require 'provision/image/catalogue'
require 'provision/image/commands'

define "copyboot" do
  extend Provision::Image::Commands

  grow

  run("loopback devices") {
    cmd "mkdir #{spec[:temp_dir]}"
    #cmd "cp /mnt/generic.img #{spec[:image_path]}"
    #    cmd "dd if=/mnt/generic.img of=/dev/mapper/MYMACHINE"
    #
    print "mounting #{spec[:image_path]} to #{spec[:temp_dir]}\n"
    cmd "mount -o offset=1048576  #{spec[:image_path]} #{spec[:temp_dir]}"
  }

  cleanup {
    cmd "umount #{spec[:temp_dir]}"
    supress_error.cmd "rmdir #{spec[:temp_dir]}"
  }

  run("set hostname") {
    open("#{spec[:temp_dir]}/etc/hostname", 'w') { |f|
      f.puts "#{spec[:hostname]}"
    }
  #    chroot "hostname -F /etc/hostname"
    open("#{spec[:temp_dir]}/etc/hosts", 'a') { |f|
      f.puts "\n127.0.0.1		localhost\n"
      f.puts "127.0.1.1		#{spec[:fqdn]}	#{spec[:hostname]}\n"
    }
    run("setup networking") {
      open("#{spec[:temp_dir]}/etc/network/interfaces", 'w') { |f|
        f.puts "
# The loopback network interface
auto lo
iface lo inet loopback
"

        spec.interfaces.each do |nic|
          f.puts "
auto #{nic[:network]}
iface #{nic[:network]} inet dhcp
"
        end
      }

      open("#{spec[:temp_dir]}/etc/dhcp/dhclient.conf", 'w') { |f|
        f.puts "
option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;
send host-name \"#{spec[:hostname]}\";
supersede domain-name \"#{spec[:domain]}\";
supersede domain-search \"#{spec[:domain]}\", \"youdevise.com\";
    "
      }
    }

    open("#{spec[:temp_dir]}/etc/udev/rules.d/70-persistent-net.rules", 'w') { |f|
      spec.interfaces.each do |nic|
        f.puts %[
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="#{nic[:mac]}", ATTR{type}=="1",  NAME="#{nic[:network]}"\n
      ]
      end
    }
  }

end

