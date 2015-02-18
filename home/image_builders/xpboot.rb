require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

### TODO: put product key in the gold.
##        move gold image production to prov tools

define "xpboot" do
  extend Provision::Image::Commands

  def xp_files
    "/var/lib/provisioning-tools/files/xpgold/"
  end

  def common_files
    "/var/lib/provisioning-tools/files/common/"
  end

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def start_menu_location
    "#{mountpoint}/Documents\ and\ Settings/All Users/Start\ Menu/Programs/Startup/"
  end

  run("copy gold image") {
    cmd "mkdir -p #{spec[:temp_dir]}"
    case config[:vm_storage_type]
    when 'lvm'
      cmd "lvcreate -n #{spec[:hostname]} -L #{spec[:image_size]} #{spec[:lvm_vg]}"
      cmd "curl -Ss --fail #{spec[:gold_image_url]} | dd of=/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      vm_disk_location = "/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      cmd "mount -o offset=32256 #{vm_disk_location} #{mountpoint}"
    when 'image'
      cmd "curl -Ss --fail -o #{spec[:image_path]} #{spec[:gold_image_url]}"
      cmd "mount -o offset=32256  #{spec[:image_path]} #{spec[:temp_dir]}"
    when 'new'
      # do nothing
    end
  }

  on_error {
    case config[:vm_storage_type]
    when 'lvm'
      if File.exists?("/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}")
        cmd "lvremove -f /dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      end
    end
  }

  run("inject hostname and ip address") {
    key = "WJG3W-CHHC2-2R97W-7BC2F-MM9JD"
    answer_file = "#{mountpoint}/sysprep/sysprep.inf"
    network_file = "#{mountpoint}/sysprep/net.txt"
    cmd "sed -i s/\"<%COMPUTERNAME%>\"/#{spec[:hostname]}/g #{answer_file}"
    cmd "sed -i s/\"<%PRODUCTKEY%>\"/#{key}/g #{answer_file}"

    gateway = "127.0.0.1"
    spec[:routes].each do |route|
      route =~ /via (.+)$/
      gateway = $1
    end

    dns_domain = spec[:dns_search_path].split(' ')[0]

    spec.interfaces.each do |nic|
      config = spec[:networking][nic[:network].to_sym]
      cmd "sed -i s/\"<%DNSDOMAIN%>\"/#{dns_domain}/g #{network_file}"
      cmd "sed -i s/\"<%DNSSERVER%>\"/#{spec[:nameserver]}/g #{network_file}"
      cmd "sed -i s/\"<%IPADDRESS%>\"/#{config[:address]}/g #{network_file}"
      cmd "sed -i s/\"<%NETMASK%>\"/#{config[:netmask]}/g #{network_file}"
      cmd "sed -i s/\"<%GATEWAY%>\"/#{gateway}/g #{network_file}"
    end
  }

  run("install Selenium") {
    selenium_dir = "#{common_files}/selenium"
    java_dir     = "#{common_files}/java"
    start_menu_grid_file = "#{mountpoint}/selenium/start-grid.bat"

    FileUtils.rm_r "#{mountpoint}/selenium", :force => true
    FileUtils.cp_r selenium_dir, "#{mountpoint}"

    FileUtils.rm_r "#{mountpoint}/java", :force => true
    FileUtils.cp_r java_dir, "#{mountpoint}"

    cmd "sed -i s/%SEVERSION%/#{spec[:selenium_version]}/g \"#{start_menu_grid_file}\""

    if spec[:selenium_version] == "2.41.0"
      cmd "sed -i s/browserName=\\\\*iexplore%IEVERSION%,/browserName=*iexplore,/g \"#{start_menu_grid_file}\""
      FileUtils.mv "#{mountpoint}/selenium/IEDriverServer.exe", "#{mountpoint}/selenium/IEDriverServer-2.32.0.exe"
      FileUtils.cp "#{mountpoint}/selenium/IEDriverServer-2.41.0.exe", "#{mountpoint}/selenium/IEDriverServer.exe"
    end
    cmd "sed -i s/%IEVERSION%/#{spec[:ie_version]}/g \"#{start_menu_grid_file}\""
  }

  run("Configure and start Selenium node on boot") {
    start_menu_grid_file = "#{mountpoint}/selenium/start-grid.bat"

    if spec[:selenium_hub_host]
      cmd "sed -i s/%HUBHOST%/#{spec[:selenium_hub_host]}/g \"#{start_menu_grid_file}\""
      cmd "rm \"#{start_menu_location}\"/*"
      FileUtils.cp start_menu_grid_file, start_menu_location
    end
  }

  run("Apply registry settings on first boot") {
    FileUtils.cp "#{xp_files}/startmenu/apply-reg-settings.bat", start_menu_location
  }

  run("stamp time") {
     tmp_date_file = "#{mountpoint}/build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  }

  case config[:vm_storage_type]
  when 'lvm', 'image'
    cleanup {
      cmd "umount -l #{mountpoint}"
      cmd "sleep 1"
      suppress_error.cmd "rmdir #{mountpoint}"
    }
  when 'new'
    # do nothing
  end

end
