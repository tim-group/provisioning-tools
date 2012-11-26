define rabbitmq::create_user ($password) {
  Exec {
    path    => ['/bin','/usr/bin','/usr/sbin'],
    require => Class['rabbitmq::install'],
    before  => Class['rabbitmq::post_config'],
  }
  exec {
    "/usr/sbin/rabbitmqctl add_user ${name} ${password} ; /usr/sbin/rabbitmqctl set_permissions -p / ${name} '.*' '.*' '.*'":
      onlyif => "/usr/bin/test `/usr/sbin/rabbitmqctl list_users | grep ${name} | wc -l` -eq 0",
  }
}

