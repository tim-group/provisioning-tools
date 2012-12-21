class mcollective::service {
  include puppetmaster::wait_for

  service { 'mcollective':
     ensure  => running,
     enable  => true,
     require => [Class['mcollective::install'], Exec['waitfor_puppetmaster']];
  }
}
