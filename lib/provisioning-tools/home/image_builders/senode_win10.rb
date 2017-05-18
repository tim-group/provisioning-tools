require 'provisioning-tools/provision/image/catalogue'
require 'provisioning-tools/provision/image/commands'
require 'socket'

define "senode_win10" do
  extend Provision::Image::Commands

  def common_files
    "/var/lib/provisioning-tools/files/common/"
  end

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def sysprep_answer_file
    "#{mountpoint}/Windows/Panther/unattend.xml"
  end

  def start_menu_location
    "#{mountpoint}/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Startup/"
  end

  run("copy gold image") do
    win10_partition_location = 525_336_576
    case config[:vm_storage_type]
    when 'lvm', 'image'
      cmd "mkdir -p #{spec[:temp_dir]}"
    when 'new'
      # do nothing
    end

    case config[:vm_storage_type]
    when 'lvm'
      cmd "lvcreate -n #{spec[:hostname]} -L #{spec[:image_size]} #{spec[:lvm_vg]}"
      cmd "curl -Ss --fail #{spec[:gold_image_url]} | dd of=/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      vm_disk_location = "/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      cmd "mount -o offset=#{win10_partition_location} #{vm_disk_location} #{mountpoint}"
    when 'image'
      cmd "curl -Ss --fail -o #{spec[:image_path]} #{spec[:gold_image_url]}"
      cmd "mount -o offset=#{win10_partition_location} #{spec[:image_path]} #{mountpoint}"
    when 'new'
      # do nothing now mounted by storage service.
    end
  end

  on_error do
    case config[:vm_storage_type]
    when 'lvm'
      if File.exists?("/dev/#{spec[:lvm_vg]}/#{spec[:hostname]}")
        cmd "lvremove -f /dev/#{spec[:lvm_vg]}/#{spec[:hostname]}"
      end
    end
  end

  run("Remove batch file which initates a fresh sysprep on boot") do
    FileUtils.rm "#{start_menu_location}/dosysprep.bat"
  end

  run("inject hostname and ip address") do
    gateway = "127.0.0.1"
    spec[:routes].each do |route|
      route =~ /via (.+)$/
      gateway = Regexp.last_match(1)
    end

    dns_domain = spec[:dns_search_path].split(' ')[0]

    spec.interfaces.each do |nic|
      config = spec[:networking][nic[:network].to_sym]
      cmd "sed -i s/%%COMPUTERNAME%%/#{spec[:hostname]}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%DNSDOMAIN%%/#{dns_domain}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%DNSSERVER%%/#{spec[:nameserver]}/g #{sysprep_answer_file}"
      # FIXME: prov-tools can do multiple IPs per adaptor, but unsure how to do
      # that with sysprep. So default to prior behaviour
      cmd "sed -i s/%%IPADDRESS%%/#{config.first[:address]}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%GATEWAY%%/#{gateway}/g #{sysprep_answer_file}"
    end
  end

  run("install Selenium") do
    selenium_dir = "#{common_files}/selenium"
    java_dir     = "#{common_files}/java"
    start_menu_grid_file = "#{mountpoint}/selenium/start-grid.bat"
    standalone_launch_file = "#{mountpoint}/selenium/start-standalone.bat"
    edge_driver_version = '4.15063'

    FileUtils.rm_r "#{mountpoint}/selenium", :force => true
    FileUtils.cp_r selenium_dir, "#{mountpoint}"

    FileUtils.rm_r "#{mountpoint}/java", :force => true
    FileUtils.cp_r java_dir, "#{mountpoint}"

    cmd "sed -i s/%SEVERSION%/#{spec[:selenium_version]}/g \"#{start_menu_grid_file}\""
    cmd "sed -i s/%SEVERSION%/#{spec[:selenium_version]}/g \"#{standalone_launch_file}\""

    cmd "sed -i s/browserName=\\\\*iexplore%IEVERSION%,/browserName=*iexplore,/g \"#{start_menu_grid_file}\""
    cmd "sed -i s/%IEVERSION%/11/g \"#{start_menu_grid_file}\""
    cmd "sed -i s/%IEVERSION%/11/g \"#{standalone_launch_file}\""
    FileUtils.mv "#{mountpoint}/selenium/IEDriverServer.exe", "#{mountpoint}/selenium/IEDriverServer-2.32.0.exe"
    FileUtils.cp "#{mountpoint}/selenium/IEDriverServer-#{spec[:selenium_version]}.exe",
                 "#{mountpoint}/selenium/IEDriverServer.exe"

    edge_cfg = 'seleniumProtocol=WebDriver,browserName=MicrosoftEdge,maxInstances=1'
    cmd "sed -i 's/-singleWindow/-singleWindow -browser \"#{edge_cfg}\"/' \"#{start_menu_grid_file}\""
    cmd "sed -i 's/-singleWindow/-singleWindow -browser \"#{edge_cfg}\"/' \"#{standalone_launch_file}\""
    FileUtils.mv "#{mountpoint}/selenium/MicrosoftWebDriver-#{edge_driver_version}.exe" "#{mountpoint}/selenium/MicrosoftWebDriver.exe"
  end

  run("Configure and start Selenium node on boot") do
    if spec[:selenium_hub_host]
      start_menu_grid_file = "#{mountpoint}/selenium/start-grid.bat"

      cmd "sed -i s/%HUBHOST%/#{spec[:selenium_hub_host]}/g \"#{start_menu_grid_file}\""
      FileUtils.cp start_menu_grid_file, start_menu_location
    else
      standalone_launch_file = "#{mountpoint}/selenium/start-standalone.bat"
      FileUtils.cp standalone_launch_file, start_menu_location
    end
  end

  run("Install registry hack to make Selenium work on IE") do
    FileUtils.cp "#{mountpoint}/selenium/hack-registry.bat", start_menu_location
  end

  run("stamp time") do
    tmp_date_file = "#{mountpoint}/build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  end

  case config[:vm_storage_type]
  when 'lvm', 'image'
    cleanup do
      cmd "umount -l #{mountpoint}"
      cmd "sleep 1"
      suppress_error.cmd "rmdir #{mountpoint}"
    end
  when 'new'
    # do nothing
  end
end
