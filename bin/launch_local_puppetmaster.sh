#!/bin/bash
sudo rake network
sudo bin/dns deallocate dev-puppetmaster-001.mgmt.dev.net.local
sudo bin/dns allocate dev-puppetmaster-001.mgmt.dev.net.local
sudo sed -i 's/dev-puppetmaster-001.mgmt.dev.net.local/dev-puppetmaster-001.mgmt.dev.net.local puppet.mgmt.dev.net.local/g' /etc/hosts
sudo rake network
sudo virsh destroy dev-puppetmaster-001
sudo virsh undefine dev-puppetmaster-001
cat files/puppetmaster.yaml | sudo bin/provision
#wait for puppetmaster: to come up
#launch ref apps

