require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "xpgold" do
  extend Provision::Image::Commands

  # TODO: sysprep should cleanup start menu folder
  # TODO: copy and paste :::

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

  run ("download master image") {
    master_url = "#{spec[:master_image_url]}"
    cmd "curl -Ss --fail -o #{spec[:image_path]} #{master_url}"
    suppress_error.cmd "mkdir -p #{spec[:temp_dir]}"
    cmd "mount -o offset=32256  #{spec[:image_path]} #{spec[:temp_dir]}"
  }

  cleanup {
    cmd "umount -l #{spec[:temp_dir]}"
    cmd "sleep 1"
    suppress_error.cmd "rmdir #{spec[:temp_dir]}"
  }

  run("install sysprep") {
    cmd "rm \"#{start_menu_location}\"/*"
    FileUtils.mkdir_p("#{mountpoint}/settings")
    FileUtils.cp_r("#{xp_files}/support/", "#{mountpoint}/")
    FileUtils.cp_r("#{xp_files}/sysprep/", "#{mountpoint}/")
    FileUtils.cp "#{xp_files}/startmenu/dosysprep.bat", start_menu_location
    FileUtils.cp "#{xp_files}/startmenu/apply-reg-settings.bat", start_menu_location
  }

  run("install Selenium") {
    selenium_dir = "#{common_files}/selenium"
    java_dir     = "#{common_files}/java"
    start_menu_grid_file = "#{mountpoint}/selenium/start-grid.bat"

    FileUtils.cp_r selenium_dir, "#{mountpoint}"
    FileUtils.cp_r java_dir, "#{mountpoint}"

    cmd "sed -i s/%SEVERSION%/#{spec[:selenium_version]}/g \"#{start_menu_grid_file}\""
    cmd "sed -i s/%IEVERSION%/#{spec[:ie_version]}/g \"#{start_menu_grid_file}\""
  }

  run("stamp gold image build date") {
    tmp_date_file="#{mountpoint}/gold-build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  }

  run("write ie version to file") {
    File.open("#{mountpoint}/ieversion.txt", 'w') do
      |file| file.write(spec[:ieversion])
    end
  }
end
