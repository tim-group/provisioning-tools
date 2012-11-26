class rabbitmq {
  include rabbitmq::install,
          rabbitmq::service,
          rabbitmq::config,
          rabbitmq::plugins
}
