#!/bin/bash
set -u

if (( EUID != 0 )); then
   echo "You sudo this." 1>&2
   exit 100
fi

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENVIRONMENT="${1:-${env:-dev}}"

rake network
"${BIN}"/dns deallocate "${ENVIRONMENT}-puppetmaster-001.mgmt.dev.net.local"
"${BIN}"/dns allocate "${ENVIRONMENT}-puppetmaster-001.mgmt.dev.net.local"
sed -i 's/^\(.*puppet.mgmt.dev.net.local.*\)$/#\1/' /etc/hosts
sed -i "s/${ENVIRONMENT}-puppetmaster-001.mgmt.dev.net.local/${ENVIRONMENT}-puppetmaster-001.mgmt.dev.net.local puppet.mgmt.dev.net.local/g" /etc/hosts
rake network
virsh destroy "${ENVIRONMENT}-puppetmaster-001"
virsh undefine "${ENVIRONMENT}-puppetmaster-001"
cat files/puppetmaster.yaml | sed "s/dev-puppetmaster-001/${ENVIRONMENT}-puppetmaster-001/g" | "${BIN}"/provision

#wait for puppetmaster: to come up
#launch ref apps

