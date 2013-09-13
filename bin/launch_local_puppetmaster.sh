#!/bin/bash
set -u

if (( EUID != 0 )); then
   echo "You sudo this." 1>&2
   exit 100
fi

env="${1:-${env:-dev}}"

rake network
bin/dns deallocate "${env}-puppetmaster-001.mgmt.dev.net.local"
bin/dns allocate "${env}-puppetmaster-001.mgmt.dev.net.local"
sed -i "s/dev-puppetmaster-001.mgmt.dev.net.local/${env}-puppetmaster-001.mgmt.dev.net.local puppet.mgmt.dev.net.local/g" /etc/hosts
rake network
virsh destroy "${env}-puppetmaster-001"
virsh undefine "${env}-puppetmaster-001"
cat files/puppetmaster.yaml | sed "s/dev-puppetmaster-001/${env}-puppetmaster-001/g" | bin/provision

#wait for puppetmaster: to come up
#launch ref apps

