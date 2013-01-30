class puppetagent($puppetmaster) {
  class {'puppetmaster::wait_for':
    puppetmaster => $puppetmaster
  }

  file {'puppet_conf':
    path    => '/etc/puppet/puppet.conf',
    content => template('puppetagent/puppet.conf.erb')
  }

  exec { 'generate_csr':
    cwd       => '/tmp',
    command   => "puppetd -t",
    path      => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    require   => [Class['puppetmaster::wait_for'], File['puppet_conf']],
    returns   => 1,
    logoutput => true
  }

}
