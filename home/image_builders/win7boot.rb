require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "win7boot" do
  extend Provision::Image::Commands

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def start_menu_location
    "#{mountpoint}/Documents\ and\ Settings/All Users/Start\ Menu/Programs/Startup/"
  end

  run("copy gold image") {
    cmd "mkdir -p #{spec[:temp_dir]}"
    #cmd "curl --fail -o #{spec[:image_path]} #{spec[:gold_image_url]}"
    cmd "mv #{spec[:gold_image_url]} #{spec[:image_path]}"
    cmd "mount -o offset=105906176 #{spec[:image_path]} #{spec[:temp_dir]}"
  }

  cleanup {
    cmd "umount #{spec[:temp_dir]}"
  }

  run("inject hostname and ip address") {
  }

  run("configure_launch_script") {
  }

  run("stamp time") {
     tmp_date_file="#{mountpoint}/build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  }

end
