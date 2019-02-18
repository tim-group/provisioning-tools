require 'provisioning-tools/provision/image/catalogue'
require 'provisioning-tools/provision/image/commands'
require 'socket'

IPAddr.class_eval do
  def to_cidr
    "/" + to_i.to_s(2).count("1").to_s
  end
end

define "copybootbionic" do
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

    open("#{spec[:temp_dir]}/etc/hosts", 'w') do |f|
      f.puts "127.0.0.1		localhost\n"
      f.puts "127.0.1.1		#{spec[:fqdn]}	#{spec[:hostname]}\n"
    end
  end

  run("setup networking for bionic") do
    open("#{spec[:temp_dir]}/etc/netplan/01-netcfg.yaml", 'w') do |f|
      f.puts <<-HEREDOC
network:
  version: 2
  renderer: networkd
  ethernets:
      HEREDOC

      spec.interfaces.each do |nic|
        config = spec[:networking][nic[:network].to_sym]
        next unless !config.nil?
        config.sort_by { |hsh| hsh[:address] }.each do |net|
          f.puts <<-HEREDOC
    #{nic[:network]}:
      match:
        macaddress: "#{nic[:mac]}"
      set-name: #{nic[:network]}
      addresses: [ "#{net[:address]}#{IPAddr.new(net[:netmask]).to_cidr}" ]
      nameservers:
        addresses: [ "#{spec[:nameserver]}" ]
        search: [ #{spec[:dns_search_path].gsub(' ', ', ')} ]
    HEREDOC
        end
      end
    end

    open("#{spec[:temp_dir]}/etc/cron.d/netplan-apply", 'w') do |f|
      f.puts "@reboot root /usr/sbin/netplan apply"
      f.puts "@reboot root sed -i 's/Domains/\#Domains/g' /etc/systemd/resolved.conf"
      f.puts "@reboot root systemctl restart systemd-resolved"
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
