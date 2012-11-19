class mcollective::config {

  File {
    require => Class['mcollective::install'],
  }

  # Configure it
  file {
    '/etc/mcollective':
      ensure => directory;

    '/etc/mcollective/server.cfg':
      ensure  => file,
      mode    => '0400',
      owner   => 'root',
      group   => 'root',
      content => template('mcollective/server.cfg.erb');
  }
}

