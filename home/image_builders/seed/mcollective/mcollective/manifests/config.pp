class mcollective::config {

  File {
    require => Class['mcollective::install'],
  }

  # Configure it
  file {

     [ '/etc/mcollective', '/etc/mcollective/ssl', '/etc/mcollective/ssl/clients', '/etc/mcollective/extra_facts.d' ]:
       ensure => directory;

    '/etc/mcollective/server.cfg':
      ensure  => file,
      mode    => '0400',
      owner   => 'root',
      group   => 'root',
      content => template('mcollective/server.cfg.erb');

     '/etc/mcollective/ssl/server-private.pem':
       ensure => file,
       source => 'puppet:///modules/mcollective/ssl/server-private.pem';

     '/etc/mcollective/ssl/clients/server-public.pem':
       ensure => file,
       source => 'puppet:///modules/mcollective/ssl/clients/server-public.pem';

     '/etc/mcollective/ssl/server-public.pem':
       ensure  => link,
       target  => '/etc/mcollective/ssl/clients/server-public.pem';

 #    '/etc/mcollective/policies':
 #      source  => 'puppet:///modules/mcollective/policies',
 #      recurse => true,
 #      purge   => true;

  }
}

