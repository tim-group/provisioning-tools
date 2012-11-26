class activemq::install {

  Package {
    require => Class["activemq::config"]
  }

  package { 'activemq':
    ensure  => present
  }
}
