define serial::console( $serial_port = 'ttyS0' ) {
  file { "/etc/init/${serial_port}.conf":
    content => template('serial/etc/init/ttySX.conf.erb'),
    mode    => '0644',
    owner   => root,
    group   => root,
  }
}
