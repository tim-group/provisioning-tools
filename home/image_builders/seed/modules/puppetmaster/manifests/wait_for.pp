class puppetmaster::wait_for($puppetmaster = "localhost") {
  exec { 'waitfor_puppetmaster':
    cwd         => '/tmp',
    command     => "curl http://${puppetmaster}:8140",
    try_sleep   => 1,
    tries       => 60,
    path        => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    require => Service['apache2-puppetmaster'];
  }
}
