require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "win7boot_finalise" do
  extend Provision::Image::Commands

  def win7_files
    "/var/lib/provisioning-tools/files/win7gold/"
  end

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def sysprep_answer_file
    "#{mountpoint}/unattend.xml"
  end

  def start_menu_location
    "#{mountpoint}/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Startup/"
  end

  run("remove sysprep") {
    cmd "mount -o offset=#{win7_partition_location} #{spec[:image_path]} #{mountpoint}"
    FileUtils.rm "#{mountpoint}/unattend.xml"
    FileUtils.rm "#{start_menu_location}/dosysprep.bat"
  }

  cleanup {
    cmd "umount -l #{mountpoint}"
    cmd "sleep 1"
    suppress_error.cmd "rmdir #{mountpoint}"
  }

end
