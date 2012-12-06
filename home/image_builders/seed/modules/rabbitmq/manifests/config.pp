class rabbitmq::config {
  Package {
    require => Class["rabbitmq::install"]
  }

  rabbitmq::create_user { 'mcollective':
    password => 'so6aeh9tieD2';
  }

}

