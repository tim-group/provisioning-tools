class apt_cacher_ng::install {
  package { 'apt-cacher-ng':
    ensure => present,
  }
}
