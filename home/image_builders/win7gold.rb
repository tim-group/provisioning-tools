require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "win7gold" do
  extend Provision::Image::Commands

  def win7_files
    "/var/lib/provisioning-tools/files/win7gold/"
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
