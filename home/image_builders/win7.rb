require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "win7" do
  extend Provision::Image::Commands

  def win7_files
    "/var/lib/provisioning-tools/files/win7gold/"
  end

  def common_files
    "/var/lib/provisioning-tools/files/common/"
  end

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def sysprep_answer_file
    "#{mountpoint}/sysprep/unattend.xml"
  end

  def start_menu_location
    "#{mountpoint}/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Startup/"
  end

  run("copy master image") {
    win7_partition_location = 105906176
    cmd "mkdir -p #{spec[:temp_dir]}"
    #cmd "curl --fail -o #{spec[:image_path]} #{spec[:master_image_url]}"
    cmd "mv #{spec[:master_image_url]} #{spec[:image_path]}"
    cmd "mount -o offset=#{win7_partition_location} #{spec[:image_path]} #{mountpoint}"
  }

  run("install sysprep") {
    FileUtils.cp_r "#{win7_files}/sysprep/", "#{mountpoint}"
    FileUtils.cp "#{win7_files}/startmenu/dosysprep.bat", start_menu_location
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
      cmd "sed -i s/%%DNSDOMAIN%%/#{dns_domain}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%DNSSERVER%%/#{spec[:nameserver]}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%IPADDRESS%%/#{config[:address]}/g #{sysprep_answer_file}"
      cmd "sed -i s/%%GATEWAY%%/#{gateway}/g #{sysprep_answer_file}"
    end
  }

  run("install Selenium") {
    if spec[:selenium]
      start_menu_grid_file = "#{mountpoint}/selenium/start-grid.bat"
      selenium_dir = "#{common_files}/selenium"
      java_dir     = "#{common_files}/java"
      selenium = spec[:selenium]

      FileUtils.cp_r selenium_dir, "#{mountpoint}"
      FileUtils.cp_r java_dir, "#{mountpoint}"

      spec[:ie_version] = `cat #{mountpoint}/ieversion.txt`.chomp unless spec[:ie_version]
      cmd "sed -i s/%HUBHOST%/#{selenium[:hub_host]}/g \"#{start_menu_grid_file}\""
      cmd "sed -i s/%SEVERSION%/#{selenium[:version]}/g \"#{start_menu_grid_file}\""
      cmd "sed -i s/%IEVERSION%/#{spec[:ie_version]}/g \"#{start_menu_grid_file}\""
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
