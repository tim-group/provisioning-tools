class apt_cacher_ng::service {
  service { 'apt-cacher-ng':
    ensure    => running,
    enable    => true,
    hasstatus => false,
    require   => Class['apt_cacher_ng::install'],
    subscribe => Class['apt_cacher_ng::config'],
  }
}
