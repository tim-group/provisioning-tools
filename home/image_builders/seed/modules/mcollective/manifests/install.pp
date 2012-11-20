class mcollective::install {

  # Install it
  package {
     [ 'libstomp-ruby1.8', 'libstomp-ruby', 'ruby-stomp' ]:
       ensure => installed;

     [ 'mcollective', 'mcollective-common' ]:
       ensure  => '2.2.0-2',
       require => Package['libstomp-ruby1.8', 'libstomp-ruby', 'ruby-stomp'];
  }
}

