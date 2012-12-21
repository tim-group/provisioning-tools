class puppetdb::wait_for($puppetmaster = "localhost") {
  exec { 'waitfor_puppetdb':
    cwd         => '/tmp',
    command     => "curl -H 'Accept: application/json' 'http://${puppetmaster}:8080/metrics/mbean/com.puppetlabs.puppetdb.query.population:type=default,name=num-resources'",
    try_sleep   => 1,
    tries       => 60,
    refreshonly => true,
    path        => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin';
  }
}
