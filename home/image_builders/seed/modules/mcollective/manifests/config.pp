class mcollective::config($broker) {

  $collective = 'mcollective'
  # Configure it
  file {

    [ '/etc/mcollective',
    '/etc/mcollective/ssl',
    '/etc/mcollective/ssl/clients',
    '/usr/share/mcollective/',
    '/usr/share/mcollective/plugins'

    ]:
      ensure => directory;

    '/etc/mcollective/server.cfg':
      ensure  => file,
      mode    => '0400',
      owner   => 'root',
      group   => 'root',
      content => template('mcollective/server.cfg.erb'),
      notify => Class['mcollective::service'];

    '/etc/mcollective/ssl/server-private.pem':
      ensure => file,
      source => 'puppet:///modules/mcollective/ssl/server-private.pem';

    '/etc/mcollective/ssl/clients/server-public.pem':
      ensure => file,
      source => 'puppet:///modules/mcollective/ssl/clients/server-public.pem';

    '/etc/mcollective/ssl/server-public.pem':
      ensure  => link,
      target  => '/etc/mcollective/ssl/clients/server-public.pem';

    '/etc/mcollective/ssl/clients/seed.pem':
      ensure => $ensure,
      owner  => 'root',
      group  => 'root',
      mode   => '0400',
      source => 'puppet:///modules/mcollective/ssl/clients/seed.pem';

    '/usr/share/mcollective/plugins/mcollective/':
      ensure   => directory,
      source   => 'puppet:///modules/mcollective/plugins',
      require => File['/usr/share/mcollective/plugins'],
      recurse => true;
  }
}
