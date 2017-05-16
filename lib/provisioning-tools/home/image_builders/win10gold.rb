require 'provisioning-tools/provision/image/catalogue'
require 'provisioning-tools/provision/image/commands'
require 'socket'

define "win10gold" do
  extend Provision::Image::Commands

  def win10_files
    "/var/lib/provisioning-tools/files/win10gold/"
  end

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def start_menu_location
    "#{mountpoint}/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Startup/"
  end

  case config[:vm_storage_type]
  when "image"
    run("copy master image") do
      win10_partition_location = 105_906_176
      cmd "curl -Ss --fail -o #{spec[:image_path]} #{spec[:master_image_url]}"
      cmd "mkdir -p #{mountpoint}"
      cmd "mount -o offset=#{win10_partition_location} #{spec[:image_path]} #{mountpoint}"
    end

    cleanup do
      cmd "umount -l #{mountpoint}"
      cmd "sleep 1"
      suppress_error.cmd "rmdir #{mountpoint}"
    end
  when "new"
    # do nothing
  else
    fail "Unsure how to build win10gold with vm_storage_type of #{config[:vm_storage_type]}"
  end

  run("install sysprep") do
    FileUtils.cp_r "#{win10_files}/sysprep/", "#{mountpoint}"
    FileUtils.cp "#{win10_files}/startmenu/dosysprep.bat", start_menu_location
  end

  run("stamp gold image build date") do
    tmp_date_file = "#{mountpoint}/gold-build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  end
end
