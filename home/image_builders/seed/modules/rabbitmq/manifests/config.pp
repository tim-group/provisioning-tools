class rabbitmq::config {
  Package {
    require => Class["rabbitmq::install"]
  }

  file {
    ['/etc/rabbitmq']:
      ensure => directory;

    '/etc/rabbitmq/rabbitmq.config':
      source => 'puppet:///rabbitmq/rabbitmq.config';

  }
  rabbitmq::create_user { 'mcollective':
    password => 'marionette';
  }

}

