#!/bin/bash
$(dirname "$0")/git-cloneinto http://git/git/puppet /etc/puppet
/usr/sbin/puppetdb-ssl-setup
