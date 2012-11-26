define rabbitmq::plugin {
  exec {
    "/usr/sbin/rabbitmq-plugins enable rabbitmq_${name}":
      onlyif  => "/usr/bin/test `/usr/sbin/rabbitmq-plugins list | grep ${name} | grep \\[E\\] | wc -l` -eq 0",
      require => Class['rabbitmq::install'],
      notify  => Class['rabbitmq::service'];
  }
}

