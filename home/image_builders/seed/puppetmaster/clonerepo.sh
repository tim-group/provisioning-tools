#!/bin/bash
rm -rf /etc/puppet
git clone http://git/git/puppet /etc/puppet/
puppetca generate dev-puppetmaster-001.dev.net.local
puppet-ssl-setup
