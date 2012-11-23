class activemq::service {
  service{'activemq':
    ensure    => running,
    enable    => true,
    hasstatus => true,
    require   => Class['activemq::install'],
    subscribe => Class['activemq::config'],
  }
}
