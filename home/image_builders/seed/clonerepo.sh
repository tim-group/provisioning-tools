#!/bin/bash
rm -rf /etc/puppet && \
git clone http://git/git/puppet /etc/puppet/ && \
/usr/sbin/puppetdb-ssl-setup
