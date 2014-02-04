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

  def sysprep_answer_file
    "#{mountpoint}/unattend.xml"
  end

  def start_menu_location
    "#{mountpoint}/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Startup/"
  end

  run("copy master image") {
    win7_partition_location = 105906176
    cmd "curl --fail -o #{spec[:image_path]} #{spec[:master_image_url]}"
    cmd "mkdir -p #{mountpoint}"
    cmd "mount -o offset=#{win7_partition_location} #{spec[:image_path]} #{mountpoint}"
  }

  run("install sysprep") {
    FileUtils.cp "#{win7_files}/sysprep/unattend.xml", "#{sysprep_answer_file}"
    FileUtils.cp "#{win7_files}/startmenu/dosysprep.bat", start_menu_location
  }

  run("stamp gold image build date") {
    tmp_date_file="#{mountpoint}/gold-build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  }

  run("write ie version to file") {
    File.open("#{mountpoint}/ieversion.txt", 'w') do |file|
      file.write(spec[:ieversion])
    end
  }

  cleanup {
    cmd "umount -l #{mountpoint}"
    cmd "sleep 1"
    suppress_error.cmd "rmdir #{mountpoint}"
  }

end
