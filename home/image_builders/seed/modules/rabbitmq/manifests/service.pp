class rabbitmq::service {
    service {'rabbitmq-server':
        ensure     => running,
        enable     => true,
        provider   => debian,
        hasrestart => true,
        hasstatus  => true,
        require    => Class['rabbitmq::install'];
    }
}

