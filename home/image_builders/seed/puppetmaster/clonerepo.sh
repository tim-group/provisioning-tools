#!/bin/bash
rm -rf /etc/puppet && \
git clone http://git/git/puppet /etc/puppet/ && \
/usr/sbin/puppetca generate dev-puppetmaster-001.dev.net.local && \
/usr/sbin/puppetdb-ssl-setup
