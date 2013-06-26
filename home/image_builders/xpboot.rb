require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

### TODO: put product key in the gold.
##        move gold image production to prov tools

define "xpboot" do
  extend Provision::Image::Commands

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def start_menu_location
    "#{mountpoint}/Documents\ and\ Settings/All Users/Start\ Menu/Programs/Startup/"
  end

  run("copy gold image") {
#    spec[:gold_image_path] = "/mnt/dev-seliex-goldtest.img"
    cmd "mkdir -p #{spec[:temp_dir]}"
    cmd "cp #{spec[:gold_image_path]} #{spec[:image_path]}"
    cmd "mount -o offset=32256  #{spec[:image_path]} #{spec[:temp_dir]}"
  }

  cleanup {
    cmd "umount #{spec[:temp_dir]}"
   # suppress_error.cmd "rmdir #{spec[:temp_dir]}"
  }

  run("inject hostname and ip address") {
    key="WJG3W-CHHC2-2R97W-7BC2F-MM9JD"
    answer_file="#{mountpoint}/sysprep/sysprep.inf"
    network_file="#{mountpoint}/sysprep/net.txt"
    cmd "sed -i s/\"<%COMPUTERNAME%>\"/#{spec[:hostname]}/g #{answer_file}"
    cmd "sed -i s/\"<%PRODUCTKEY%>\"/#{key}/g #{answer_file}"

    gateway = "127.0.0.1"
    spec[:routes].each do |route|
      route =~ /via (.+)$/
      gateway = $1
    end

    dns_domain = spec[:dns_search_path].split(' ')[0]

    spec.interfaces.each do |nic|
      config = spec[:networking][nic[:network].to_sym]
      cmd "sed -i s/\"<%DNSDOMAIN%>\"/#{dns_domain}/g #{network_file}"
      cmd "sed -i s/\"<%DNSSERVER%>\"/#{spec[:nameserver]}/g #{network_file}"
      cmd "sed -i s/\"<%IPADDRESS%>\"/#{config[:address]}/g #{network_file}"
      cmd "sed -i s/\"<%NETMASK%>\"/#{config[:netmask]}/g #{network_file}"
      cmd "sed -i s/\"<%GATEWAY%>\"/#{gateway}/g #{network_file}"
    end
  }

  run("configure_launch_script") {
    xp_files = File.join(File.dirname(__FILE__), "../../files/xpboot/")
    start_menu_grid_file = "#{start_menu_location}#{spec[:launch_script]}"
    launch_script = "#{xp_files}/#{spec[:launch_script]}"

    selenium_dir = "#{xp_files}/selenium"
    java_dir     = "#{xp_files}/java"

    FileUtils.cp_r selenium_dir, "#{spec[:temp_dir]}"
    FileUtils.cp_r java_dir, "#{spec[:temp_dir]}"

    cmd "rm \"#{start_menu_location}\"/*"
    FileUtils.cp launch_script, start_menu_location

    spec[:ie_version] = `cat #{spec[:temp_dir]}/ieversion.txt`.chomp unless spec[:ie_version]

    cmd "sed -i s/\"%HUBHOST%\"/#{spec[:se_hub]}/g \"#{start_menu_grid_file}\""
    cmd "sed -i s/\"%SEVERSION%\"/#{spec[:se_version]}/g \"#{start_menu_grid_file}\""
    cmd "sed -i s/\"%IEVERSION%\"/#{spec[:ie_version]}/g \"#{start_menu_grid_file}\""
  }

  run("stamp time") {
     tmp_date_file="#{mountpoint}/build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  }

end
