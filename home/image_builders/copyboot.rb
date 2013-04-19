require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "copyboot" do
  extend Provision::Image::Commands

  grow

  run("loopback devices") {
    cmd "mkdir #{spec[:temp_dir]}"
    #cmd "cp /mnt/generic.img #{spec[:image_path]}"
    #    cmd "dd if=/mnt/generic.img of=/dev/mapper/MYMACHINE"
    #
    #print "mounting #{spec[:image_path]} to #{spec[:temp_dir]}\n"
    pp spec
    cmd "mount -o offset=1048576  #{spec[:image_path]} #{spec[:temp_dir]}"
  }

  cleanup {
    cmd "umount #{spec[:temp_dir]}"
    suppress_error.cmd "rmdir #{spec[:temp_dir]}"
  }

  run("set hostname") {
    open("#{spec[:temp_dir]}/etc/hostname", 'w') { |f|
      f.puts "#{spec[:hostname]}"
    }

    open("#{spec[:temp_dir]}/etc/resolv.conf", 'w') { |f|
      f.puts %[domain mgmt.#{spec[:domain]}
nameserver #{spec[:nameserver]}
search #{spec[:dns_search_path]}
]
    }

    open("#{spec[:temp_dir]}/etc/dhcp/dhclient.conf", 'w') { |f|
      f.puts ""
    }

    open("#{spec[:temp_dir]}/etc/network/if-up.d/routes_mgmt", 'w') { |f|
      f.puts %[#!/bin/bash\nif [ "${IFACE}" == "mgmt" ]; then\n]
      spec[:routes].each do |route|
        f.puts %[ip route add #{route}]
      end
      f.puts %[fi]
    }

    cmd "chmod a+x #{spec[:temp_dir]}/etc/network/if-up.d/routes_mgmt"

    #   chroot "hostname -F /etc/hostname"
    open("#{spec[:temp_dir]}/etc/hosts", 'a') { |f|
      f.puts "\n127.0.0.1		localhost\n"
      f.puts "127.0.1.1		#{spec[:fqdn]}	#{spec[:hostname]}\n"
    }
  }

  run("setup networking") {
    open("#{spec[:temp_dir]}/etc/network/interfaces", 'w') { |f|
      f.puts "
# The loopback network interface
auto lo
iface lo inet loopback
    "

      spec.interfaces.each do |nic|
        config = spec[:networking][nic[:network].to_sym]
        if config != nil
          f.puts "
auto #{nic[:network]}
iface #{nic[:network]} inet static
address #{config[:address]}
netmask   #{config[:netmask]}
"
        else
          f.puts "
auto #{nic[:network]}
iface #{nic[:network]} inet manual
"
          open("#{spec[:temp_dir]}/etc/network/if-up.d/manual_up_#{nic[:network]}", 'w') { |fo|
          fo.puts "
#!/bin/bash
if [\"${IFACE}\" == \"#{nic[:network]}\" ]; then
ip link set dev #{nic[:network]} up
fi
"
          }
        end
      end
    }

    open("#{spec[:temp_dir]}/etc/udev/rules.d/70-persistent-net.rules", 'w') { |f|

    }

    open("#{spec[:temp_dir]}/etc/udev/rules.d/70-persistent-net.rules", 'w') { |f|
      spec.interfaces.each do |nic|
        f.puts %[
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="#{nic[:mac]}", ATTR{type}=="1",  NAME="#{nic[:network]}"\n
      ]
      end
    }
  }

  run("configure aptproxy") {
    open("#{spec[:temp_dir]}/etc/apt/apt.conf.d/01proxy", 'w') { |f|
      f.puts "Acquire::http::Proxy \"http://#{spec[:aptproxy]}:3142\";\n"
    }
  }

  run("set parent fact") {
    cmd "mkdir -p #{spec[:temp_dir]}/etc/facts.d"
    open("#{spec[:temp_dir]}/etc/facts.d/parent.fact", 'w') { |f|
      f.puts "parent=#{Socket.gethostname}\n"
    }
  }

end
