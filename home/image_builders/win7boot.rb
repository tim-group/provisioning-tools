require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "win7boot" do
  extend Provision::Image::Commands

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def sysprep_answer_file
    "#{mountpoint}/Windows/Panther/unattend.xml"
  end

  def start_menu_location
    "#{mountpoint}/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Startup/"
  end

  run("copy gold image") {
    win7_partition_location = 105906176
    cmd "mkdir -p #{spec[:temp_dir]}"

    case config[:vm_storage_type]
    when 'lvm'
      cmd "lvcreate -n #{spec[:hostname]} -L #{spec[:image_size]} #{spec[:lvm_vg]}"
      cmd "curl -Ss --fail #{spec[:gold_image_url]} | dd of=/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      vm_disk_location = "/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      cmd "mount -o offset=#{win7_partition_location} #{vm_disk_location} #{mountpoint}"
    when 'image'
      cmd "curl -Ss --fail -o #{spec[:image_path]} #{spec[:gold_image_url]}"
      cmd "mount -o offset=#{win7_partition_location} #{spec[:image_path]} #{mountpoint}"
    end
  }

  on_error {
    case config[:vm_storage_type]
    when 'lvm'
      if File.exists("/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}")
        cmd "lvremove -f /dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      end
    end
  }

  run("Remove batch file which initates a fresh sysprep on boot") {
    FileUtils.rm "#{start_menu_location}/dosysprep.bat"
  }

  run("inject hostname and ip address") {
    gateway = "127.0.0.1"
    spec[:routes].each do |route|
      route =~ /via (.+)$/
      gateway = $1
    end

    dns_domain = spec[:dns_search_path].split(' ')[0]

    spec.interfaces.each do |nic|
      config = spec[:networking][nic[:network].to_sym]
      cmd "sed -i s/%%COMPUTERNAME%%/#{spec[:hostname]}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%DNSDOMAIN%%/#{dns_domain}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%DNSSERVER%%/#{spec[:nameserver]}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%IPADDRESS%%/#{config[:address]}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%GATEWAY%%/#{gateway}/g #{sysprep_answer_file}"
    end
  }

  run("Configure and start Selenium node on boot") {
    if spec[:selenium_hub_host]
      start_menu_grid_file = "#{mountpoint}/selenium/start-grid.bat"

      cmd "sed -i s/%HUBHOST%/#{spec[:selenium_hub_host]}/g \"#{start_menu_grid_file}\""
      FileUtils.cp start_menu_grid_file, start_menu_location
    end
  }

  run("stamp time") {
     tmp_date_file="#{mountpoint}/build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  }

  cleanup {
    cmd "umount -l #{mountpoint}"
    cmd "sleep 1"
    suppress_error.cmd "rmdir #{mountpoint}"
  }

end
