define "senode_trusty" do
  copyboot

  run('install rc.local') do
    selenium_version = spec[:selenium_version] || "2.53.1"
    selenium_node_version = spec[:selenium_node_version] || "3.0.7"
    firefox_version = spec[:firefox_version] || "47.0.1-0ubuntu1"
    chrome_version = spec[:chrome_version] || "52.0.2743.116-1"
    se_host = spec[:selenium_hub_host]
    se_port = "7799"

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') do |f|
      f.puts "#!/bin/sh -e\n" \
        "if [ -e /var/lib/firstboot ]; then exit 0; fi\n" \
        "echo 'Running rc.local' | logger\n" \
        "apt-get -y --force-yes update\n" \
        "/usr/sbin/adduser --disabled-password --gecos '' ci\n" \
        "apt-get -y --force-yes install zulu-8\n" \
        "sed -i'.bak' -e 's#^securerandom.source=.*#securerandom.source=file:/dev/./urandom#'" \
        " /usr/lib/jvm/zulu-8-amd64/jre/lib/security/java.security\n" \
        "apt-get -y --force-yes install acpid xvfb dbus dbus-x11 hicolor-icon-theme\n" \
        "apt-get -y --force-yes install firefox=#{firefox_version}\n" \
        "ln -s /usr/lib/firefox/firefox /usr/bin/firefox-bin\n" \
        "apt-get -y --force-yes install google-chrome-stable=#{chrome_version}\n" \
        "apt-get -y --force-yes install selenium=#{selenium_version}\n" \
        "apt-get -y --force-yes install selenium-node=#{selenium_node_version}\n" \
        "update-rc.d selenium-node defaults\n" \
        "echo 'HUBHOST=#{se_host}' > /etc/default/selenium-node\n" \
        "echo 'HUBPORT=#{se_port}' >> /etc/default/selenium-node\n" \
        "/etc/init.d/selenium-node start\n" \
        "echo 'Generated by /etc/rc.local to mark that the first boot setup has been performed' > /var/lib/firstboot\n" \
        "echo 'Finished running rc.local'\n" \
        "exit 0\n"
    end
  end
end
