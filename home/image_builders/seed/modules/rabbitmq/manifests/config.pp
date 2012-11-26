class rabbitmq::config {
  Package {
    require => Class["rabbitmq::install"]
  }

  rabbitmq::create_user { 'mcollective':
    password => 'marionette';
  }

}

