class waitfor_puppetmaster {
  exec { 'wait_for_curl_puppetmaster':
    cwd         => '/tmp',
    command     => "curl 'http://localhost:8140'",
    try_sleep   => 2,
    tries       => 480,
    refreshonly => true,
    path        => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin';
  }
end
