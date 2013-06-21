require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

# TODO: no final shutdown -- reboot?
#       ip injection
#       hub url injection
#
define "xpboot" do
  extend Provision::Image::Commands
#  extend Provision::Image::WinXP

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def start_menu_location
    "#{mountpoint}/Documents\ and\ Settings/All Users/Start\ Menu/Programs/Startup/"
  end

  run("copy gold image") {
    spec[:gold_image_path] = "/mnt/dev-seliex-goldtest.img"
    cmd "mkdir -p #{spec[:temp_dir]}"
    cmd "mv #{spec[:gold_image_path]} #{spec[:image_path]}"
    cmd "mount -o offset=32256  #{spec[:image_path]} #{spec[:temp_dir]}"
  }

  cleanup {
    cmd "umount #{spec[:temp_dir]}"
    #suppress_error.cmd "rmdir #{spec[:temp_dir]}"
  }

  run("inject hostname and ip address") {
    key="WJG3W-CHHC2-2R97W-7BC2F-MM9JD"
    answer_file="#{mountpoint}/sysprep/sysprep.inf"
    network_file="#{mountpoint}/sysprep/net.txt"
    cmd "sed -i s/\"<%COMPUTERNAME%>\"/#{spec[:hostname]}/g #{answer_file}"
    cmd "sed -i s/\"<%PRODUCTKEY%>\"/#{key}/g #{answer_file}"



    pp "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

    spec.interfaces.each do |nic|
      config = spec[:networking][nic[:network].to_sym]
      print "sed -i s/\"<%DNSSERVER%>\"/192.168.5.1/g #{network_file}"

      cmd "sed -i s/\"<%DNSSERVER%>\"/192.168.5.1/g #{network_file}"
      cmd "sed -i s/\"<%IPADDRESS%>\"/#{config[:address]}/g #{network_file}"
      cmd "sed -i s/\"<%NETMASK%>\"/#{config[:netmask]}/g #{network_file}"
      cmd "sed -i s/\"<%GATEWAY%>\"/192.168.5.1/g #{network_file}"
    end
  }

  run("configure_launch_script") {
    FileUtils.rm_rf "#{start_menu_location}/*"
    FileUtils.cp "#{mountpoint}/selenium/#{spec[:launch_script]}", start_menu_location
  }

  run("stamp time") {
     tmp_date_file="#{mountpoint}/build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  }

end
