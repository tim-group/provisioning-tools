class puppetagent($puppetmaster) {
  file {'puppet_conf':
    path    => '/etc/puppet/puppet.conf',
    content => template('puppetagent/puppet.conf.erb')
  }
}
