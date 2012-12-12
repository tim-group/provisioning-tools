class apt_cacher_ng::config {
  file { '/etc/apt-cacher-ng':
    ensure  => directory,
    mode    => '0644',
    require => Class['apt_cacher_ng::install'],
  }

  file { '/etc/apt-cacher-ng/security.conf':
    ensure  => file,
    mode    => '0644',
    require => Class['apt_cacher_ng::install'],
    source  => 'puppet:///modules/apt_cacher_ng/security.conf',
    owner   => 'apt-cacher-ng',
    group   => 'apt-cacher-ng',
  }

  file { '/etc/apt-cacher-ng/acng.conf':
    ensure  => file,
    source  => 'puppet:///modules/apt_cacher_ng/acng.conf',
    require => Class['apt_cacher_ng::install'],
  }

  file { '/usr/lib/apt-cacher-ng/userinfo.html':
    ensure  => file,
    require => Class['apt_cacher_ng::install'],
    source  => 'puppet:///modules/apt_cacher_ng/userinfo.html',
  }

  file { '/usr/lib/apt-cacher-ng/report.html':
    ensure  => file,
    require => Class['apt_cacher_ng::install'],
    source  => 'puppet:///modules/apt_cacher_ng/report.html',
  }
}
