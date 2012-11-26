class rabbitmq::post_config {

  file {
    ['/etc/rabbitmq']:
      ensure => directory;

    '/etc/rabbitmq/rabbitmq.config':
      source => 'puppet:///rabbitmq/rabbitmq.config',
      notify => Class['rabbitmq::service'];

  }

}

