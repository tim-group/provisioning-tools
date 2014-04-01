require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "win7gold" do
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

  def start_menu_location
    "#{mountpoint}/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Startup/"
  end

  run("copy master image") {
    win7_partition_location = 105906176
    cmd "curl -Ss --fail -o #{spec[:image_path]} #{spec[:master_image_url]}"
    cmd "mkdir -p #{mountpoint}"
    cmd "mount -o offset=#{win7_partition_location} #{spec[:image_path]} #{mountpoint}"
  }

  run("install sysprep") {
    FileUtils.cp_r "#{win7_files}/sysprep/", "#{mountpoint}"
    FileUtils.cp "#{win7_files}/startmenu/dosysprep.bat", start_menu_location
  }

  run("install Selenium") {
    selenium_dir = "#{common_files}/selenium"
    java_dir     = "#{common_files}/java"
    start_menu_grid_file = "#{mountpoint}/selenium/start-grid.bat"

    FileUtils.cp_r selenium_dir, "#{mountpoint}"
    FileUtils.cp_r java_dir, "#{mountpoint}"

    cmd "sed -i s/%SEVERSION%/#{spec[:selenium_version]}/g \"#{start_menu_grid_file}\""

    if spec[:selenium_version] == "2.41.0"
        cmd "sed -i s/browserName=\\\\*iexplore%IEVERSION%,/browserName=*iexplore,/g \"#{start_menu_grid_file}\""
        FileUtils.mv "#{mountpoint}/selenium/IEDriverServer.exe", "#{mountpoint}/selenium/IEDriverServer-2.32.0.exe"
        FileUtils.cp "#{mountpoint}/selenium/IEDriverServer-2.41.0.exe", "#{mountpoint}/selenium/IEDriverServer.exe"
    end
    cmd "sed -i s/%IEVERSION%/#{spec[:ie_version]}/g \"#{start_menu_grid_file}\""
  }

  run("stamp gold image build date") {
    tmp_date_file="#{mountpoint}/gold-build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  }

  cleanup {
    cmd "umount -l #{mountpoint}"
    cmd "sleep 1"
    suppress_error.cmd "rmdir #{mountpoint}"
  }

end
