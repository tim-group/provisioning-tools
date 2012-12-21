class puppetagent($puppetmaster) {
  class {'puppetmaster::wait_for':
    puppetmaster => $puppetmaster
  }

  file {'puppet_conf':
    path    => '/etc/puppet/puppet.conf',
    content => template('puppetagent/puppet.conf.erb')
  }
}
