class mcollective::install {

  Package {
    require => Class["mcollective::config"]
  }

  package {
     [ 'libstomp-ruby1.8', 'libstomp-ruby', 'ruby-stomp' ]:
       ensure => installed;

     [ 'mcollective', 'mcollective-common', 'mcollective-plugins-puppetd' ]:
       ensure  => '2.2.0-2',
       require => Package['libstomp-ruby1.8', 'libstomp-ruby', 'ruby-stomp'];
  }
}

