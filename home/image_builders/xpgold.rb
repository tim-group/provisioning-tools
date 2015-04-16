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

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def start_menu_location
    "#{spec[:temp_dir]}/Documents\ and\ Settings/All Users/Start\ Menu/Programs/Startup/"
  end

  case config[:vm_storage_type]
  when "image"
    run("download master image") do
      master_url = "#{spec[:master_image_url]}"
      cmd "curl -Ss --fail -o #{spec[:image_path]} #{master_url}"
      suppress_error.cmd "mkdir -p #{spec[:temp_dir]}"
      cmd "mount -o offset=32256  #{spec[:image_path]} #{spec[:temp_dir]}"
    end

    cleanup do
      cmd "umount -l #{spec[:temp_dir]}"
      cmd "sleep 1"
      suppress_error.cmd "rmdir #{spec[:temp_dir]}"
    end
  when "new"
    # do nothing
  else
    raise "Unsure how to build xpgold with vm_storage_type of #{config[:vm_storage_type]}"
  end

  run("install sysprep") do
    cmd "rm \"#{start_menu_location}\"/*"
    FileUtils.mkdir_p("#{mountpoint}/settings")
    FileUtils.cp_r("#{xp_files}/support/", "#{spec[:temp_dir]}/")
    FileUtils.cp_r("#{xp_files}/sysprep/", "#{spec[:temp_dir]}/")
    FileUtils.cp "#{xp_files}/startmenu/dosysprep.bat", start_menu_location
  end

  run("stamp gold image build date") do
    tmp_date_file = "#{spec[:temp_dir]}/gold-build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  end
end
