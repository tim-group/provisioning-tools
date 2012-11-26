class rabbitmq::plugins {
  Package {
    require => Class["rabbitmq::install"]
  }

  rabbitmq::plugin { 'stomp': }

}

