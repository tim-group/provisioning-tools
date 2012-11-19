class mcollective::plugins {

  File {
    require => Class['mcollective::config'],
  }

  # Add plugins
  file { '/usr/share/mcollective/plugins/mcollective/registration/meta.rb':
    ensure => present,
    source => 'puppet:///modules/mcollective/registration/meta.rb';
  }

}

