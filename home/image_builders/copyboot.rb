require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "copyboot" do
  extend Provision::Image::Commands

  grow

  case config[:vm_storage_type]
  when 'image', 'lvm'
    run("create temporary mount directory for VM filesystem") do
      cmd "mkdir #{spec[:temp_dir]}"
    end
  end

  case config[:vm_storage_type]
  when 'image'
    run("mount loopback device") do
      cmd "mount -o offset=1048576 #{spec[:image_path]} #{spec[:temp_dir]}"
    end
  when 'lvm'
    run("mount lvm device") do
      # FIXME: We should probably do this for images too, rather than using an offset.
      vm_partition_name = cmd "kpartx -l /dev/#{spec[:lvm_vg]}/#{spec[:hostname]} | awk '{ print $1 }'"
      cmd "mount /dev/mapper/#{vm_partition_name} #{spec[:temp_dir]}"
    end
  when 'new'
    # do nothing
  end

  case config[:vm_storage_type]
  when 'image', 'lvm'
    cleanup do
      cmd "umount #{spec[:temp_dir]}"
      suppress_error.cmd "rmdir #{spec[:temp_dir]}"
    end
  when 'new'
    # do nothing
  end

  run("set hostname") do
    open("#{spec[:temp_dir]}/etc/hostname", 'w') do |f|
      f.puts "#{spec[:hostname]}"
    end

    open("#{spec[:temp_dir]}/etc/resolv.conf", 'w') do |f|
      f.puts %(domain mgmt.#{spec[:domain]}
nameserver #{spec[:nameserver]}
search #{spec[:dns_search_path]}

)
    end

    open("#{spec[:temp_dir]}/etc/dhcp/dhclient.conf", 'w') do |f|
      f.puts ""
    end

    open("#{spec[:temp_dir]}/etc/network/if-up.d/routes_mgmt", 'w') do |f|
      f.puts %(#!/bin/bash
if [ "${IFACE}" == "mgmt" ]; then
)
      spec[:routes].each do |route|
        f.puts %(ip route add #{route})
      end
      f.puts %(fi)
    end

    cmd "chmod a+x #{spec[:temp_dir]}/etc/network/if-up.d/routes_mgmt"

    open("#{spec[:temp_dir]}/etc/hosts", 'a') do |f|
      f.puts "\n127.0.0.1		localhost\n"
      f.puts "127.0.1.1		#{spec[:fqdn]}	#{spec[:hostname]}\n"
    end
  end

  run("setup networking") do
    open("#{spec[:temp_dir]}/etc/network/interfaces", 'w') do |f|
      f.puts "
# The loopback network interface
auto lo
iface lo inet loopback
    "

      spec.interfaces.each do |nic|
        config = spec[:networking][nic[:network].to_sym]
        if !config.nil?
          f.puts "
auto #{nic[:network]}
iface #{nic[:network]} inet static
address #{config[:address]}
netmask #{config[:netmask]}
"
        else
          f.puts "
auto #{nic[:network]}
iface #{nic[:network]} inet manual
"
          open("#{spec[:temp_dir]}/etc/network/if-up.d/manual_up_#{nic[:network]}", 'w') do |fo|
            fo.puts "
  #!/bin/bash
  if [\"${IFACE}\" == \"#{nic[:network]}\" ]; then
  ip link set dev #{nic[:network]} up
  fi
  "
          end
        end
      end
    end

    open("#{spec[:temp_dir]}/etc/udev/rules.d/70-persistent-net.rules", 'w') do |_f|
    end

    open("#{spec[:temp_dir]}/etc/udev/rules.d/70-persistent-net.rules", 'w') do |f|
      spec.interfaces.each do |nic|
        f.puts %(
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="#{nic[:mac]}", ATTR{type}=="1", NAME="#{nic[:network]}"
            )
      end
    end
  end

  run("configure aptproxy") do
    open("#{spec[:temp_dir]}/etc/apt/apt.conf.d/01proxy", 'w') do |f|
      f.puts "Acquire::http::Proxy \"http://#{spec[:aptproxy]}:3142\";\n"
    end
  end

  run("set owner fact") do
    fact = '/etc/facts.d/owner.fact'
    if File.exists?(fact)
      cmd "mkdir -p #{spec[:temp_dir]}/etc/facts.d"
      cmd "cp /etc/facts.d/owner.fact #{spec[:temp_dir]}/etc/facts.d"
    end
  end
end
