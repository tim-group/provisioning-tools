class mcollective::install {

  Package {
    require => Class["mcollective::config"]
  }

  package {
     [ 'libstomp-ruby1.8', 'libstomp-ruby', 'ruby-stomp' ]:
       ensure => installed;

     [ 'mcollective', 'mcollective-common' ]:
       ensure  => latest,
       require => Package['libstomp-ruby1.8', 'libstomp-ruby', 'ruby-stomp'];

  }
}

