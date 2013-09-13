#!/bin/bash
set -e
set -u

env="${1:-${env:-dev}}"

sudo rake network
sudo bin/dns deallocate "${env}-puppetmaster-001.mgmt.dev.net.local"
sudo bin/dns allocate "${env}-puppetmaster-001.mgmt.dev.net.local"
sudo sed -i "s/dev-puppetmaster-001.mgmt.dev.net.local/${env}-puppetmaster-001.mgmt.dev.net.local puppet.mgmt.dev.net.local/g" /etc/hosts
sudo rake network
sudo virsh destroy "${env}-puppetmaster-001"
sudo virsh undefine "${env}-puppetmaster-001"
cat files/puppetmaster.yaml | sed "s/dev-puppetmaster-001/${env}-puppetmaster-001/g" | sudo bin/provision

#wait for puppetmaster: to come up
#launch ref apps

